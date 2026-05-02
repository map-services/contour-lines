# Contour Lines UK Pipeline

.PHONY: all clean serve tiles

# Default target: build everything
all: tiles

# 1. Generate list of tile URLs
uk_tiles.txt: uk_tiles.py
	@echo "\033[36m→ Generating tile list...\033[0m"
	uv run --with requests python3 uk_tiles.py --check

# 2. Build virtual mosaic
uk_dem.vrt: uk_tiles.txt
	@echo "\033[36m→ Building VRT...\033[0m"
	gdalbuildvrt -q -input_file_list uk_tiles.txt uk_dem.vrt

# 3. Generate contour lines (10m)
tmp/contours_uk.gpkg: uk_dem.vrt
	@mkdir -p tmp
	@echo "\033[36m→ Generating contours...\033[0m"
	gdal_contour \
		-a elev \
		-i 10 \
		-nln contours \
		uk_dem.vrt \
		tmp/contours_uk.gpkg

# 4. Convert to MBTiles using Tippecanoe
data/mbtiles/contours_uk.mbtiles: tmp/contours_uk.gpkg
	@mkdir -p data/mbtiles
	@echo "\033[36m→ Running Tippecanoe...\033[0m"
	ogr2ogr -f GeoJSON /vsistdout/ tmp/contours_uk.gpkg | tippecanoe \
		--output=$@ \
		--layer=contours \
		--minimum-zoom=6 \
		--maximum-zoom=14 \
		--simplification=10 \
		--coalesce-densest-as-needed \
# 		--read-parallel \
		--force \
		/dev/stdin

# Shortcut to build tiles
tiles: data/mbtiles/contours_uk.mbtiles

# Serve the map
serve:
	@echo "\033[32m→ Starting TileServer GL...\033[0m"
	docker run -p 8080:8080 \
		-v $(shell pwd)/data:/data \
		maptiler/tileserver-gl \
		--config /data/config.json \
		--public_url=http://localhost:8080

# Clean workspace
clean:
	@echo "\033[33m→ Cleaning workspace...\033[0m"
	rm -f uk_tiles.txt uk_dem.vrt
	rm -rf tmp/*.gpkg tmp/*.geojson
	rm -f data/mbtiles/contours_uk.mbtiles
