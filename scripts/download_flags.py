#!/usr/bin/env python3
"""Download US state flag SVGs from Wikimedia Commons into assets/flags/.

Usage (from repo root):
    python scripts/download_flags.py

Re-run safely — already-downloaded files are skipped.
"""
import os
import time
import urllib.parse
import urllib.request

# postal → Wikimedia Commons file name (verified June 2026)
STATES = {
    'AL': 'Flag_of_Alabama.svg',
    'AK': 'Flag_of_Alaska.svg',
    'AZ': 'Flag_of_Arizona.svg',
    'AR': 'Flag_of_Arkansas.svg',
    'CA': 'Flag_of_California.svg',
    'CO': 'Flag_of_Colorado.svg',
    'CT': 'Flag_of_Connecticut.svg',
    'DE': 'Flag_of_Delaware.svg',
    'FL': 'Flag_of_Florida.svg',
    'GA': 'Flag_of_the_State_of_Georgia.svg',
    'HI': 'Flag_of_Hawaii.svg',
    'ID': 'Flag_of_Idaho.svg',
    'IL': 'Flag_of_Illinois.svg',
    'IN': 'Flag_of_Indiana.svg',
    'IA': 'Flag_of_Iowa.svg',
    'KS': 'Flag_of_Kansas.svg',
    'KY': 'Flag_of_Kentucky.svg',
    'LA': 'Flag_of_Louisiana.svg',
    'ME': 'Flag_of_the_State_of_Maine.svg',
    'MD': 'Flag_of_Maryland.svg',
    'MA': 'Flag_of_Massachusetts.svg',
    'MI': 'Flag_of_Michigan.svg',
    'MN': 'Flag_of_Minnesota.svg',
    'MS': 'Flag_of_Mississippi.svg',
    'MO': 'Flag_of_Missouri.svg',
    'MT': 'Flag_of_Montana.svg',
    'NE': 'Flag_of_Nebraska.svg',
    'NV': 'Flag_of_Nevada.svg',
    'NH': 'Flag_of_New_Hampshire.svg',
    'NJ': 'Flag_of_New_Jersey.svg',
    'NM': 'Flag_of_New_Mexico.svg',
    'NY': 'Flag_of_New_York.svg',
    'NC': 'Flag_of_North_Carolina.svg',
    'ND': 'Flag_of_North_Dakota.svg',
    'OH': 'Flag_of_Ohio.svg',
    'OK': 'Flag_of_Oklahoma.svg',
    'OR': 'Flag_of_Oregon.svg',
    'PA': 'Flag_of_Pennsylvania.svg',
    'RI': 'Flag_of_Rhode_Island.svg',
    'SC': 'Flag_of_South_Carolina.svg',
    'SD': 'Flag_of_South_Dakota.svg',
    'TN': 'Flag_of_Tennessee.svg',
    'TX': 'Flag_of_Texas.svg',
    'UT': 'Flag_of_Utah.svg',
    'VT': 'Flag_of_Vermont.svg',
    'VA': 'Flag_of_Virginia.svg',
    'WA': 'Flag_of_Washington.svg',
    'WV': 'Flag_of_West_Virginia.svg',
    'WI': 'Flag_of_Wisconsin.svg',
    'WY': 'Flag_of_Wyoming.svg',
}

BASE_URL = 'https://commons.wikimedia.org/wiki/Special:FilePath/{}'
OUT_DIR = os.path.join('assets', 'flags')

HEADERS = {
    'User-Agent': 'StateTheStatesApp/1.0 (educational Flutter app; '
                  'contact omerblecher@gmail.com)',
}


def download_flags() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    failed: list[str] = []

    for postal, filename in sorted(STATES.items()):
        out_path = os.path.join(OUT_DIR, f'{postal.lower()}.svg')
        if os.path.exists(out_path):
            print(f'  [skip] {postal}')
            continue

        url = BASE_URL.format(urllib.parse.quote(filename))
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()

            if b'<svg' not in data and b'<?xml' not in data:
                print(f'  [WARN] {postal}: response may not be SVG '
                      f'({len(data):,} bytes) — check {out_path}')

            with open(out_path, 'wb') as f:
                f.write(data)
            print(f'  [ ok] {postal}: {len(data):,} bytes')

        except Exception as exc:  # noqa: BLE001
            print(f'  [FAIL] {postal}: {exc}')
            failed.append(postal)

        time.sleep(0.3)  # be polite to Wikimedia servers

    print()
    if failed:
        print(f'Failed ({len(failed)}): {", ".join(failed)}')
        print('Re-run the script to retry.')
    else:
        print(f'All {len(STATES)} flags saved to {OUT_DIR}/')


if __name__ == '__main__':
    download_flags()
