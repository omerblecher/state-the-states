"""
generate_states.py — Build-time map data pipeline for State States.

Converts Natural Earth admin-1 (10m, public domain) into
assets/map/usa_states_paths.json containing SVG-style path strings,
centroids, bounding boxes, and pre-baked Alaska/Hawaii inset coordinates
for all 50 states + DC (51 records total).

Projection strategy (D-01, D-02, D-08):
  CONUS + DC  → EPSG:5070 (NAD83 / Conus Albers)
  Alaska      → EPSG:3338 (NAD83 / Alaska Albers) after antimeridian split
  Hawaii      → ESRI:102007-equivalent proj4 (Hawaii Albers)

Run:
    python scripts/generate_states.py
    python scripts/generate_states.py --input /path/to/ne_10m_admin_1.zip

Requirements (scripts/requirements.txt):
    geopandas>=1.0, shapely>=2.0, pyproj>=3.6.0, antimeridian>=0.4
"""

import argparse
import json
import os

import antimeridian
import geopandas as gpd
from shapely.geometry import MultiPolygon, Polygon, shape
from shapely.ops import unary_union
import shapely
from shapely.validation import explain_validity

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

NE_URL = (
    "https://naciscdn.org/naturalearth/10m/cultural/"
    "ne_10m_admin_1_states_provinces.zip"
)

# 50 USPS state codes (canonical entity set — DC handled separately, D-03/D-04)
FIFTY_STATES = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
}
DC_POSTAL = "DC"
ALL_RECORDS = FIFTY_STATES | {DC_POSTAL}  # 51 records

# Hawaii Albers proj4 — equivalent to ESRI:102007 / d3 albersUsa Hawaii projection
# Source: d3/d3-geo albersUsa.js parallels [8,18]; epsg.io/102007
HI_PROJ4 = (
    "+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 "
    "+x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs"
)

CANVAS_WIDTH = 1000

# D-08: Alaska is scaled to ~0.45× of its natural projected size
AK_SCALE_FACTOR = 0.45

# Output path (relative to project root; script is run from project root)
OUTPUT_PATH = os.path.join("assets", "map", "usa_states_paths.json")

# Optional: render a PNG for visual AK/HI inset verification
# Set RENDER_PNG = True to emit render_output.png alongside the JSON.
RENDER_PNG = False


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def fix_antimeridian(geom):
    """
    Fix a shapely geometry that crosses the 180° antimeridian (e.g. Alaska Aleutians).
    Must be called on EPSG:4326 geometry BEFORE to_crs() — DATA-02 gate.
    """
    fixed_geojson = antimeridian.fix_shape(geom)
    return shape(fixed_geojson)


def normalize_bounds(gdf_projected, canvas_width=CANVAS_WIDTH):
    """
    Derive canvas height from projected aspect ratio (D-07: derived viewBox, not hardcoded).
    Returns (canvas_height, to_canvas_fn) where to_canvas_fn maps (proj_x, proj_y) → (cx, cy).
    The y-axis is flipped so SVG/canvas coordinates increase downward.
    """
    minx, miny, maxx, maxy = gdf_projected.total_bounds
    proj_w = maxx - minx
    proj_h = maxy - miny
    canvas_height = round(canvas_width * proj_h / proj_w)

    def to_canvas(x, y):
        cx = round((x - minx) / proj_w * canvas_width, 2)
        cy = round((maxy - y) / proj_h * canvas_height, 2)  # y flipped (SVG coords)
        return cx, cy

    return canvas_height, to_canvas


def polygon_to_path_str(polygon, to_canvas):
    """
    Convert a shapely Polygon to an SVG-style path string using the provided
    canvas coordinate transform function.  Ported from Flags generate_map.py.
    """
    coords = list(polygon.exterior.coords)[:-1]  # drop repeated closing vertex
    if len(coords) < 3:
        return None
    cx0, cy0 = to_canvas(coords[0][0], coords[0][1])
    parts = [f"M{cx0},{cy0}"]
    for x, y in coords[1:]:
        cx, cy = to_canvas(x, y)
        parts.append(f"L{cx},{cy}")
    parts.append("Z")
    return " ".join(parts)


def geometry_to_paths(geom, to_canvas):
    """
    Extract all path strings from a geometry (Polygon or MultiPolygon).
    Returns (paths_list, all_xs, all_ys) for bounding box computation.
    """
    polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
    all_paths = []
    all_xs = []
    all_ys = []
    for poly in polys:
        if not isinstance(poly, Polygon):
            continue
        path = polygon_to_path_str(poly, to_canvas)
        if path:
            all_paths.append(path)
        for x, y in list(poly.exterior.coords):
            cx, cy = to_canvas(x, y)
            all_xs.append(cx)
            all_ys.append(cy)
    return all_paths, all_xs, all_ys


def largest_representative_point(geom, to_canvas):
    """
    Returns centroid (cx, cy) in canvas space using the Flags representative_point() pattern:
    pick the largest polygon in a MultiPolygon so the centroid always falls inside the
    main territory, not in overseas territory or across a border.
    """
    try:
        if isinstance(geom, MultiPolygon):
            largest = max(geom.geoms, key=lambda p: p.area)
        else:
            largest = geom
        rep = largest.representative_point()
        return to_canvas(rep.x, rep.y)
    except Exception:
        # Fallback: use merged geometry
        merged = unary_union([geom])
        rep = merged.representative_point()
        return to_canvas(rep.x, rep.y)


def build_record(postal, name, geom, to_canvas, is_placeable, inset_group):
    """
    Build a single state JSON record from projected geometry + canvas transform.
    Schema: {postal, name, paths[], boundingBox{x,y,w,h}, centroid{x,y}, isPlaceable, insetGroup}
    """
    all_paths, all_xs, all_ys = geometry_to_paths(geom, to_canvas)
    cx, cy = largest_representative_point(geom, to_canvas)

    min_x, max_x = min(all_xs), max(all_xs)
    min_y, max_y = min(all_ys), max(all_ys)

    return {
        "postal": postal,
        "name": name,
        "paths": all_paths,
        "boundingBox": {
            "x": round(min_x, 2),
            "y": round(min_y, 2),
            "w": round(max_x - min_x, 2),
            "h": round(max_y - min_y, 2),
        },
        "centroid": {"x": round(cx, 2), "y": round(cy, 2)},
        "isPlaceable": is_placeable,
        "insetGroup": inset_group,
    }


# ---------------------------------------------------------------------------
# Inset baking helpers (D-08)
# ---------------------------------------------------------------------------


def compute_inset_transform(natural_canvas_bounds, target_rect):
    """
    Compute (scale, translate_x, translate_y) to fit the natural canvas-space landmass
    into the target rectangle (preserving aspect ratio, centering within the rect).

    natural_canvas_bounds: (min_x, min_y, max_x, max_y) of the landmass in natural canvas space
    target_rect: (x0, y0, w, h) target rectangle in CONUS canvas space

    Returns (s, tx, ty) such that: canvas_coord_final = coord_natural * s + (tx, ty)
    """
    nat_min_x, nat_min_y, nat_max_x, nat_max_y = natural_canvas_bounds
    tgt_x, tgt_y, tgt_w, tgt_h = target_rect

    nat_w = nat_max_x - nat_min_x
    nat_h = nat_max_y - nat_min_y

    # Scale to fit within target rect (maintain aspect ratio — use the limiting dimension)
    s = min(tgt_w / nat_w, tgt_h / nat_h)

    scaled_w = nat_w * s
    scaled_h = nat_h * s

    # Center within target rect
    center_offset_x = (tgt_w - scaled_w) / 2.0
    center_offset_y = (tgt_h - scaled_h) / 2.0

    tx = tgt_x + center_offset_x - nat_min_x * s
    ty = tgt_y + center_offset_y - nat_min_y * s

    return s, tx, ty


def apply_inset_to_canvas(x, y, s, tx, ty):
    return round(x * s + tx, 2), round(y * s + ty, 2)


def bake_inset_transform(record, to_canvas_natural, s, tx, ty):
    """
    Re-process a record's paths using the inset transform.
    The 'to_canvas' in the original record produced natural (pre-inset) coordinates.
    We re-apply the inset affine transform to get final canvas coordinates.

    This works directly on the path string numbers rather than re-parsing geometry,
    so we rebuild by re-processing the geometry with a wrapped to_canvas function.
    """
    # We can't easily re-parse path strings, so this function isn't used directly.
    # Instead, build_record_with_inset() uses a composed to_canvas.
    pass


def make_inset_to_canvas(to_canvas_natural, s, tx, ty):
    """
    Returns a to_canvas function that first applies the natural projection normalization,
    then applies the inset scale+translate.
    """
    def to_canvas_inset(x, y):
        cx_nat, cy_nat = to_canvas_natural(x, y)
        return apply_inset_to_canvas(cx_nat, cy_nat, s, tx, ty)
    return to_canvas_inset


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Generate usa_states_paths.json from Natural Earth admin-1 shapefile."
    )
    parser.add_argument(
        "--input", default=None,
        help="Path or URL to shapefile (zip). Defaults to Natural Earth CDN."
    )
    args = parser.parse_args()

    source = args.input or NE_URL
    print(f"Loading shapefile from: {source}")
    gdf = gpd.read_file(source).to_crs("EPSG:4326")

    # -----------------------------------------------------------------------
    # First-run field verification (MANDATORY — field names MEDIUM confidence)
    # T-02-02 mitigation: print and assert before emitting any output.
    # -----------------------------------------------------------------------
    print(f"Columns: {gdf.columns.tolist()}")

    # Handle uppercase/lowercase variant (NE version drift)
    adm0_col = None
    for candidate in ("adm0_a3", "ADM0_A3"):
        if candidate in gdf.columns:
            adm0_col = candidate
            break
    if adm0_col is None:
        raise RuntimeError(
            f"Cannot find adm0_a3/ADM0_A3 column. Available columns: {gdf.columns.tolist()}"
        )

    postal_col = None
    for candidate in ("postal", "POSTAL"):
        if candidate in gdf.columns:
            postal_col = candidate
            break
    if postal_col is None:
        raise RuntimeError(
            f"Cannot find postal/POSTAL column. Available columns: {gdf.columns.tolist()}"
        )

    name_col = None
    for candidate in ("name", "NAME", "name_en"):
        if candidate in gdf.columns:
            name_col = candidate
            break
    if name_col is None:
        raise RuntimeError(
            f"Cannot find name column. Available columns: {gdf.columns.tolist()}"
        )

    gdf_usa = gdf[gdf[adm0_col] == "USA"].copy()
    print(f"USA rows: {len(gdf_usa)}")
    print(f"Postal sample: {gdf_usa[postal_col].head(10).tolist()}")

    gdf_target = gdf_usa[gdf_usa[postal_col].isin(ALL_RECORDS)].copy()
    print(f"Target rows (50 states + DC): {len(gdf_target)}")

    # Pre-assert: exactly 50 placeable states + DC in the raw data
    placeable_postals = set(gdf_target[postal_col]) - {DC_POSTAL}
    missing_states = FIFTY_STATES - set(gdf_target[postal_col])
    if missing_states:
        raise RuntimeError(f"Missing states in shapefile: {sorted(missing_states)}")
    assert len(placeable_postals) == 50, (
        f"Expected 50 placeable states, got {len(placeable_postals)}: {sorted(placeable_postals)}"
    )
    print("Field verification passed: 50 placeable states + DC found.")

    # -----------------------------------------------------------------------
    # CONUS + DC branch — EPSG:5070 (NAD83 / Conus Albers)
    # -----------------------------------------------------------------------
    conus_mask = ~gdf_target[postal_col].isin(["AK", "HI"])
    conus_gdf = gdf_target[conus_mask].to_crs("EPSG:5070")
    canvas_height, conus_to_canvas = normalize_bounds(conus_gdf, CANVAS_WIDTH)
    print(f"Derived canvas dimensions: {CANVAS_WIDTH} x {canvas_height}")

    records = {}  # postal -> record dict

    for _, row in conus_gdf.iterrows():
        postal = row[postal_col]
        name = row[name_col]
        geom = row.geometry
        if geom is None:
            continue
        is_placeable = (postal != DC_POSTAL)  # D-03: DC is non-placeable
        record = build_record(postal, name, geom, conus_to_canvas, is_placeable, None)
        if postal in records:
            # Merge multi-row states (shouldn't happen in NE 10m but defensive)
            records[postal]["paths"].extend(record["paths"])
        else:
            records[postal] = record

    print(f"CONUS + DC records: {len(records)}")

    # -----------------------------------------------------------------------
    # Alaska branch — antimeridian split FIRST, then EPSG:3338
    # D-02 / DATA-02: fix_shape() before to_crs() prevents Aleutian smear
    # -----------------------------------------------------------------------
    ak_gdf = gdf_target[gdf_target[postal_col] == "AK"].copy()
    print(f"Alaska rows before fix: {len(ak_gdf)}")
    ak_gdf["geometry"] = ak_gdf["geometry"].apply(fix_antimeridian)
    ak_projected = ak_gdf.to_crs("EPSG:3338")

    # Validity gate (T-02-03 mitigation)
    for geom in ak_projected.geometry:
        if not shapely.is_valid(geom):
            raise RuntimeError(f"Alaska geometry invalid after antimeridian fix: {explain_validity(geom)}")
    print("Alaska geometry valid after antimeridian fix + EPSG:3338 reproject.")

    # Natural normalization (before inset baking)
    _, ak_to_canvas_natural = normalize_bounds(ak_projected, CANVAS_WIDTH)

    # Compute natural canvas bounds for AK to derive inset transform
    ak_all_xs = []
    ak_all_ys = []
    for _, row in ak_projected.iterrows():
        geom = row.geometry
        polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
        for poly in polys:
            if not isinstance(poly, Polygon):
                continue
            for x, y in list(poly.exterior.coords):
                cx, cy = ak_to_canvas_natural(x, y)
                ak_all_xs.append(cx)
                ak_all_ys.append(cy)

    ak_nat_bounds = (min(ak_all_xs), min(ak_all_ys), max(ak_all_xs), max(ak_all_ys))
    ak_nat_w = ak_nat_bounds[2] - ak_nat_bounds[0]
    ak_nat_h = ak_nat_bounds[3] - ak_nat_bounds[1]
    print(f"Alaska natural canvas bounds: {ak_nat_bounds} (w={ak_nat_w:.1f}, h={ak_nat_h:.1f})")

    # D-08: AK inset target rect — lower-left ocean overlay (classic US-map convention)
    # Target: x: 0–250, y: proportionally scaled from CLAUDE.md's 430–620 in 1000x620 space
    # Scale the target rect proportionally to the derived canvas_height
    height_scale = canvas_height / 620.0
    ak_target_x = 0
    ak_target_y = round(430 * height_scale)
    ak_target_w = 250
    ak_target_h = canvas_height - ak_target_y - 5  # fill to bottom with small margin
    ak_target_rect = (ak_target_x, ak_target_y, ak_target_w, ak_target_h)

    ak_s, ak_tx, ak_ty = compute_inset_transform(ak_nat_bounds, ak_target_rect)
    ak_to_canvas_inset = make_inset_to_canvas(ak_to_canvas_natural, ak_s, ak_tx, ak_ty)

    for _, row in ak_projected.iterrows():
        postal = row[postal_col]
        name = row[name_col]
        geom = row.geometry
        if geom is None:
            continue
        record = build_record(postal, name, geom, ak_to_canvas_inset, True, "alaska")
        if postal in records:
            records[postal]["paths"].extend(record["paths"])
        else:
            records[postal] = record

    # Actual AK inset frame rect (from the final canvas positions)
    ak_canvas_xs = []
    ak_canvas_ys = []
    for _, row in ak_projected.iterrows():
        geom = row.geometry
        polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
        for poly in polys:
            if not isinstance(poly, Polygon):
                continue
            for x, y in list(poly.exterior.coords):
                cx, cy = ak_to_canvas_inset(x, y)
                ak_canvas_xs.append(cx)
                ak_canvas_ys.append(cy)

    ak_frame = {
        "x": round(min(ak_canvas_xs), 2),
        "y": round(min(ak_canvas_ys), 2),
        "w": round(max(ak_canvas_xs) - min(ak_canvas_xs), 2),
        "h": round(max(ak_canvas_ys) - min(ak_canvas_ys), 2),
    }
    print(f"Alaska inset frame: {ak_frame}")

    # -----------------------------------------------------------------------
    # Hawaii branch — HI_PROJ4 (Hawaii Albers, d3 albersUsa equivalent)
    # -----------------------------------------------------------------------
    hi_gdf = gdf_target[gdf_target[postal_col] == "HI"].copy()
    hi_projected = hi_gdf.to_crs(HI_PROJ4)

    _, hi_to_canvas_natural = normalize_bounds(hi_projected, CANVAS_WIDTH)

    # Natural canvas bounds for HI
    hi_all_xs = []
    hi_all_ys = []
    for _, row in hi_projected.iterrows():
        geom = row.geometry
        polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
        for poly in polys:
            if not isinstance(poly, Polygon):
                continue
            for x, y in list(poly.exterior.coords):
                cx, cy = hi_to_canvas_natural(x, y)
                hi_all_xs.append(cx)
                hi_all_ys.append(cy)

    hi_nat_bounds = (min(hi_all_xs), min(hi_all_ys), max(hi_all_xs), max(hi_all_ys))
    hi_nat_w = hi_nat_bounds[2] - hi_nat_bounds[0]
    hi_nat_h = hi_nat_bounds[3] - hi_nat_bounds[1]
    print(f"Hawaii natural canvas bounds: {hi_nat_bounds} (w={hi_nat_w:.1f}, h={hi_nat_h:.1f})")

    # Hawaii inset target rect — to the right of Alaska, lower area
    # Target: x: 250–380, y: proportionally scaled from CLAUDE.md's 500–620 in 1000x620 space
    hi_target_x = ak_target_x + ak_target_w + 5   # 5px gap after AK
    hi_target_y = round(500 * height_scale)
    hi_target_w = 130
    hi_target_h = canvas_height - hi_target_y - 5  # fill to bottom with small margin
    hi_target_rect = (hi_target_x, hi_target_y, hi_target_w, hi_target_h)

    hi_s, hi_tx, hi_ty = compute_inset_transform(hi_nat_bounds, hi_target_rect)
    hi_to_canvas_inset = make_inset_to_canvas(hi_to_canvas_natural, hi_s, hi_tx, hi_ty)

    for _, row in hi_projected.iterrows():
        postal = row[postal_col]
        name = row[name_col]
        geom = row.geometry
        if geom is None:
            continue
        record = build_record(postal, name, geom, hi_to_canvas_inset, True, "hawaii")
        if postal in records:
            records[postal]["paths"].extend(record["paths"])
        else:
            records[postal] = record

    # Actual HI inset frame rect
    hi_canvas_xs = []
    hi_canvas_ys = []
    for _, row in hi_projected.iterrows():
        geom = row.geometry
        polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
        for poly in polys:
            if not isinstance(poly, Polygon):
                continue
            for x, y in list(poly.exterior.coords):
                cx, cy = hi_to_canvas_inset(x, y)
                hi_canvas_xs.append(cx)
                hi_canvas_ys.append(cy)

    hi_frame = {
        "x": round(min(hi_canvas_xs), 2),
        "y": round(min(hi_canvas_ys), 2),
        "w": round(max(hi_canvas_xs) - min(hi_canvas_xs), 2),
        "h": round(max(hi_canvas_ys) - min(hi_canvas_ys), 2),
    }
    print(f"Hawaii inset frame: {hi_frame}")

    # -----------------------------------------------------------------------
    # Final assertions before emitting
    # -----------------------------------------------------------------------
    total_records = len(records)
    placeable_count = sum(1 for r in records.values() if r["isPlaceable"])
    non_placeable = [p for p, r in records.items() if not r["isPlaceable"]]

    print(f"\nTotal records: {total_records}")
    print(f"Placeable: {placeable_count}")
    print(f"Non-placeable (DC): {non_placeable}")

    assert total_records == 51, f"Expected 51 records, got {total_records}"
    assert placeable_count == 50, f"Expected 50 placeable records, got {placeable_count}"
    assert "DC" in records, "DC record missing"
    assert not records["DC"]["isPlaceable"], "DC must be non-placeable"
    assert records["AK"]["insetGroup"] == "alaska", "AK must have insetGroup='alaska'"
    assert records["HI"]["insetGroup"] == "hawaii", "HI must have insetGroup='hawaii'"

    # -----------------------------------------------------------------------
    # Build output JSON
    # -----------------------------------------------------------------------
    states_list = sorted(records.values(), key=lambda s: s["postal"])

    output = {
        "version": 1,
        "viewBox": {"width": CANVAS_WIDTH, "height": canvas_height},
        "insetFrames": {
            "alaska": ak_frame,
            "hawaii": hi_frame,
        },
        "states": states_list,  # Key is 'states', NOT 'countries' (Pitfall 7)
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, separators=(",", ":"))

    print(f"\nWrote {OUTPUT_PATH}")
    print(f"viewBox: {output['viewBox']}")
    print(f"insetFrames: alaska={ak_frame}, hawaii={hi_frame}")
    print(f"Generated {total_records} state records ({placeable_count} placeable + 1 DC)")

    # -----------------------------------------------------------------------
    # Optional PNG render for visual AK/HI inset verification (Success Criterion #2)
    # -----------------------------------------------------------------------
    if RENDER_PNG:
        _render_png(output, canvas_height)

    return output


def _render_png(output, canvas_height):
    """
    Optional: render a simple PNG of the final map for visual inspection.
    Requires matplotlib. Not a pipeline dependency — guarded by RENDER_PNG flag.
    """
    try:
        import matplotlib.patches as mpatches
        import matplotlib.pyplot as plt
        from matplotlib.path import Path as MplPath
        import re

        fig, ax = plt.subplots(1, 1, figsize=(12, canvas_height / 1000 * 12))
        ax.set_xlim(0, CANVAS_WIDTH)
        ax.set_ylim(canvas_height, 0)  # flip Y for screen coords
        ax.set_aspect("equal")
        ax.axis("off")

        def path_str_to_mpl(path_str):
            tokens = re.findall(r"[MLZ]|[-\d.]+,[-\d.]+", path_str)
            verts = []
            codes = []
            for tok in tokens:
                if tok == "M":
                    continue
                elif tok == "Z":
                    verts.append((0, 0))
                    codes.append(MplPath.CLOSEPOLY)
                elif "," in tok:
                    x, y = map(float, tok.split(","))
                    if not verts or codes[-1] == MplPath.CLOSEPOLY:
                        codes.append(MplPath.MOVETO)
                    else:
                        codes.append(MplPath.LINETO)
                    verts.append((x, y))
            if not verts:
                return None
            return MplPath(verts, codes)

        for state in output["states"]:
            color = "#aad4f5" if state["insetGroup"] == "alaska" else (
                "#f5d0a9" if state["insetGroup"] == "hawaii" else "#dce8dc"
            )
            for path_str in state["paths"]:
                parts = path_str.split(" ")
                verts = []
                codes = []
                i = 0
                while i < len(parts):
                    tok = parts[i]
                    if tok.startswith("M"):
                        x, y = map(float, tok[1:].split(","))
                        verts.append((x, y))
                        codes.append(MplPath.MOVETO)
                    elif tok.startswith("L"):
                        x, y = map(float, tok[1:].split(","))
                        verts.append((x, y))
                        codes.append(MplPath.LINETO)
                    elif tok == "Z":
                        verts.append(verts[0])
                        codes.append(MplPath.CLOSEPOLY)
                    i += 1
                if len(verts) >= 3:
                    mpl_path = MplPath(verts, codes)
                    patch = mpatches.PathPatch(mpl_path, facecolor=color, edgecolor="gray", linewidth=0.3)
                    ax.add_patch(patch)

        # Draw inset frames
        for name, frame in output["insetFrames"].items():
            rect = mpatches.Rectangle(
                (frame["x"], frame["y"]), frame["w"], frame["h"],
                linewidth=1, edgecolor="navy", facecolor="none", linestyle="--"
            )
            ax.add_patch(rect)

        out_png = "render_output.png"
        plt.savefig(out_png, dpi=150, bbox_inches="tight")
        plt.close()
        print(f"PNG render saved to: {out_png}")
    except ImportError:
        print("matplotlib not available — skipping PNG render. Install with: pip install matplotlib")
    except Exception as e:
        print(f"PNG render failed (non-fatal): {e}")


if __name__ == "__main__":
    main()
