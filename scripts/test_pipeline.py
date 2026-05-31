"""
test_pipeline.py — Pipeline output validation for generate_states.py.

Validates:
  - test_state_count:         51 total records, 50 isPlaceable:true, 1 DC isPlaceable:false
  - test_alaska_validity:     Alaska geometry passes shapely.is_valid() after fix_shape + EPSG:3338
  - test_inset_positions:     AK centroid inside alaska insetFrame; HI centroid inside hawaii insetFrame
  - test_no_dc_placeable:     DC record has isPlaceable=false and is excluded from placeable iteration
  - test_viewbox_derived:     viewBox width=1000 and height in (600, 640)

Run:
    python -m pytest scripts/test_pipeline.py -v
    python -m pytest scripts/test_pipeline.py::test_state_count
    python -m pytest scripts/test_pipeline.py::test_alaska_validity
"""

import json
import os
import sys

import pytest
import shapely

# Ensure project root is on path so generate_states is importable
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

# Path to the generated JSON asset (relative to project root)
JSON_PATH = os.path.join(_PROJECT_ROOT, "assets", "map", "usa_states_paths.json")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def map_data():
    """Load usa_states_paths.json once for all tests in this module."""
    assert os.path.exists(JSON_PATH), (
        f"usa_states_paths.json not found at {JSON_PATH}. "
        "Run `python scripts/generate_states.py` first."
    )
    with open(JSON_PATH, encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(scope="module")
def states(map_data):
    return map_data["states"]


@pytest.fixture(scope="module")
def inset_frames(map_data):
    return map_data["insetFrames"]


# ---------------------------------------------------------------------------
# DATA-01: state count validation
# ---------------------------------------------------------------------------


def test_state_count(states):
    """
    DATA-01: Exactly 51 records total; exactly 50 are isPlaceable:true; exactly 1 is false (DC).
    """
    total = len(states)
    placeable = [s for s in states if s["isPlaceable"]]
    non_placeable = [s for s in states if not s["isPlaceable"]]

    assert total == 51, f"Expected 51 records, got {total}"
    assert len(placeable) == 50, f"Expected 50 placeable states, got {len(placeable)}"
    assert len(non_placeable) == 1, f"Expected exactly 1 non-placeable record (DC), got {len(non_placeable)}"
    assert non_placeable[0]["postal"] == "DC", (
        f"Expected non-placeable postal to be 'DC', got '{non_placeable[0]['postal']}'"
    )


# ---------------------------------------------------------------------------
# DATA-02: Alaska antimeridian validity
# ---------------------------------------------------------------------------


def test_alaska_validity():
    """
    DATA-02: Alaska geometry is valid after antimeridian.fix_shape() + to_crs('EPSG:3338').
    Re-runs the pipeline's Alaska branch directly to validate the geometry gate.
    """
    import geopandas as gpd
    from scripts.generate_states import fix_antimeridian, NE_URL

    # Use cached shapefile if available to avoid re-download
    cache_candidates = [
        os.path.join(_PROJECT_ROOT, "scripts", ".ne_cache",
                     "ne_10m_admin_1_states_provinces.zip"),
    ]
    source = NE_URL
    for candidate in cache_candidates:
        if os.path.exists(candidate):
            source = candidate
            break

    gdf = gpd.read_file(source).to_crs("EPSG:4326")

    # Find adm0_a3 column (handle case variance)
    adm0_col = next(
        (c for c in gdf.columns if c.lower() == "adm0_a3"), None
    )
    postal_col = next(
        (c for c in gdf.columns if c.lower() == "postal"), None
    )
    assert adm0_col is not None, "adm0_a3 column not found in shapefile"
    assert postal_col is not None, "postal column not found in shapefile"

    ak_rows = gdf[(gdf[adm0_col] == "USA") & (gdf[postal_col] == "AK")].copy()
    assert len(ak_rows) >= 1, "Alaska row not found in shapefile"

    # Apply fix_shape BEFORE to_crs (DATA-02 requirement)
    ak_rows["geometry"] = ak_rows["geometry"].apply(fix_antimeridian)
    ak_projected = ak_rows.to_crs("EPSG:3338")

    for geom in ak_projected.geometry:
        assert shapely.is_valid(geom), (
            f"Alaska geometry is NOT valid after fix_shape + EPSG:3338: "
            f"{shapely.validation.explain_validity(geom)}"
        )


# ---------------------------------------------------------------------------
# DATA-01/D-08: Inset position validation
# ---------------------------------------------------------------------------


def test_inset_positions(states, inset_frames):
    """
    D-08: AK centroid falls inside the alaska insetFrame; HI centroid inside hawaii insetFrame.
    Proves inset transforms were baked into path coordinates, not geographic coords.
    """
    ak_state = next((s for s in states if s["postal"] == "AK"), None)
    hi_state = next((s for s in states if s["postal"] == "HI"), None)

    assert ak_state is not None, "AK record not found in states"
    assert hi_state is not None, "HI record not found in states"

    ak_frame = inset_frames["alaska"]
    hi_frame = inset_frames["hawaii"]

    def centroid_in_frame(centroid, frame):
        cx, cy = centroid["x"], centroid["y"]
        fx, fy, fw, fh = frame["x"], frame["y"], frame["w"], frame["h"]
        return fx <= cx <= fx + fw and fy <= cy <= fy + fh

    ak_centroid = ak_state["centroid"]
    hi_centroid = hi_state["centroid"]
    ak_frame_val = inset_frames["alaska"]
    hi_frame_val = inset_frames["hawaii"]

    assert centroid_in_frame(ak_centroid, ak_frame_val), (
        f"Alaska centroid {ak_centroid} is NOT inside the alaska insetFrame {ak_frame_val}. "
        "This means inset transforms were not baked into canvas coordinates."
    )
    assert centroid_in_frame(hi_centroid, hi_frame_val), (
        f"Hawaii centroid {hi_centroid} is NOT inside the hawaii insetFrame {hi_frame_val}. "
        "This means inset transforms were not baked into canvas coordinates."
    )


# ---------------------------------------------------------------------------
# D-03/D-04: DC non-placeable exclusion
# ---------------------------------------------------------------------------


def test_no_dc_placeable(states):
    """
    D-03: The record with postal 'DC' has isPlaceable=false.
    Iterating only placeable states excludes DC from the game token set.
    """
    dc = next((s for s in states if s["postal"] == "DC"), None)
    assert dc is not None, "DC record not found in states — it must be present as a filler"
    assert dc["isPlaceable"] is False, (
        f"DC must have isPlaceable=false; got {dc['isPlaceable']}"
    )

    # Verify that iterating placeable states excludes DC
    placeable_postals = {s["postal"] for s in states if s["isPlaceable"]}
    assert "DC" not in placeable_postals, "DC appeared in the placeable iteration — it must be excluded"
    assert len(placeable_postals) == 50, (
        f"Expected 50 placeable postals, got {len(placeable_postals)}: {sorted(placeable_postals)}"
    )


# ---------------------------------------------------------------------------
# D-07: Derived viewBox dimensions
# ---------------------------------------------------------------------------


def test_viewbox_derived(map_data):
    """
    D-07: viewBox width is exactly 1000; height is in (600, 640) — derived from CONUS Albers bounds.
    A hardcoded height would violate D-07 and indicate equirectangular fallback.
    """
    vb = map_data["viewBox"]
    assert vb["width"] == 1000, f"viewBox width must be 1000, got {vb['width']}"
    assert 600 < vb["height"] < 640, (
        f"viewBox height {vb['height']} is not in the expected (600, 640) range — "
        "check that CONUS Albers normalization is deriving the height from projected bounds"
    )
