import argparse
import requests

def tile_exists(url, verbose=False):
    # Strip /vsicurl/ prefix for the HTTP request
    http_url = url.replace("/vsicurl/", "")
    response = requests.head(http_url, timeout=10)
    exists = response.status_code == 200
    if not exists and verbose:
        print(f"Skipping missing tile: {url}")
    return exists

parser = argparse.ArgumentParser(description="Generate Copernicus DEM tile list for UK")
parser.add_argument("--check", action="store_true", help="Check each tile exists before including it")
parser.add_argument("--verbose", "-v", action="store_true", help="Log skipped tiles")
args = parser.parse_args()

lats = range(49, 62)
lons = range(-9, 3)

urls = []
for lat in lats:
    for lon in lons:
        ns = f"N{lat:02d}"
        ew = f"W{abs(lon):03d}" if lon < 0 else f"E{lon:03d}"
        path = f"Copernicus_DSM_COG_10_{ns}_00_{ew}_00_DEM"
        url = f"/vsicurl/https://copernicus-dem-30m.s3.amazonaws.com/{path}/{path}.tif"
        if args.check:
            if tile_exists(url, verbose=args.verbose):
                urls.append(url)
        else:
            urls.append(url)

with open("uk_tiles.txt", "w") as f:
    f.write("\n".join(urls))

print(f"Written {len(urls)} tiles to uk_tiles.txt")