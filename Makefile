# Contour Lines UK Pipeline

.PHONY: all clean serve tiles

# ─── Directories ────────────────────────────────────────────────────────────

TMP        := tmp
MBTILES    := data/mbtiles

# ─── Intermediate files ──────────────────────────────────────────────────────

TILE_LIST  := $(TMP)/uk_tiles.txt
VRT        := $(TMP)/uk_dem.vrt
GPKG       := $(TMP)/contours_uk.gpkg

GEOJSON_100 := $(TMP)/contours_100m.geojson
GEOJSON_50  := $(TMP)/contours_50m.geojson
GEOJSON_10  := $(TMP)/contours_10m.geojson

MBTILES_Z6_7   := $(TMP)/z6_7.mbtiles
MBTILES_Z8_9   := $(TMP)/z8_9.mbtiles
MBTILES_Z10_14 := $(TMP)/z10_14.mbtiles

# ─── Final output ────────────────────────────────────────────────────────────

OUTPUT := $(MBTILES)/contours_uk.mbtiles

# ─── Default target ──────────────────────────────────────────────────────────

all: tiles

# ─── Step 1: Generate tile URL list ─────────────────────────────────────────

$(TILE_LIST): uk_tiles.py
	@echo "\033[36m→ Generating tile list...\033[0m"
	@mkdir -p $(TMP)
	uv run --with requests python3 uk_tiles.py --check --output $(TILE_LIST)

# ─── Step 2: Build virtual mosaic ────────────────────────────────────────────

$(VRT): $(TILE_LIST)
	@echo "\033[36m→ Building VRT...\033[0m"
	gdalbuildvrt -q -input_file_list $< $@

# ─── Step 3: Generate contour lines (25m interval) ───────────────────────────

$(GPKG): $(VRT)
	@echo "\033[36m→ Generating contours...\033[0m"
	gdal_contour -a elev -i 10 -nln contours $< $@

# ─── Step 4a: Extract GeoJSON at each resolution ─────────────────────────────

$(GEOJSON_100): $(GPKG)
	@echo "\033[36m→ Extracting 100m contours...\033[0m"
	ogr2ogr -f GeoJSON $@ $< -sql "SELECT * FROM contours WHERE CAST(elev AS INTEGER) % 100 = 0"

$(GEOJSON_50): $(GPKG)
	@echo "\033[36m→ Extracting 50m contours...\033[0m"
	ogr2ogr -f GeoJSON $@ $< -sql "SELECT * FROM contours WHERE CAST(elev AS INTEGER) % 50 = 0"

$(GEOJSON_10): $(GPKG)
	@echo "\033[36m→ Extracting 10m contours...\033[0m"
	ogr2ogr -f GeoJSON $@ $< -sql "SELECT * FROM contours WHERE CAST(elev AS INTEGER) % 10 = 0"

# ─── Step 4b: Tile each zoom band ────────────────────────────────────────────

$(MBTILES_Z6_7): $(GEOJSON_100)
	@echo "\033[36m→ Tiling z6–7...\033[0m"
	tippecanoe --output=$@ --layer=contours \
	  --minimum-zoom=6 --maximum-zoom=7 \
	  --simplification=5 --coalesce-densest-as-needed --force $<

$(MBTILES_Z8_9): $(GEOJSON_50)
	@echo "\033[36m→ Tiling z8–9...\033[0m"
	tippecanoe --output=$@ --layer=contours \
	  --minimum-zoom=8 --maximum-zoom=9 \
	  --simplification=5 --coalesce-densest-as-needed --force $<

$(MBTILES_Z10_14): $(GEOJSON_10)
	@echo "\033[36m→ Tiling z10–14...\033[0m"
	tippecanoe --output=$@ --layer=contours \
	  --minimum-zoom=10 --maximum-zoom=14 \
	  --simplification=5 --coalesce-densest-as-needed --force $<

# ─── Step 5: Join zoom bands into final MBTiles ──────────────────────────────

$(OUTPUT): $(MBTILES_Z6_7) $(MBTILES_Z8_9) $(MBTILES_Z10_14)
	@mkdir -p $(MBTILES)
	@echo "\033[36m→ Joining MBTiles...\033[0m"
	tile-join --output=$@ --force $^

# ─── Shortcuts ───────────────────────────────────────────────────────────────

tiles: $(OUTPUT)

serve:
	@echo "\033[32m→ Starting TileServer GL...\033[0m"
	docker run -p 8080:8080 -v $(shell pwd)/data:/data maptiler/tileserver-gl \
	  --config /data/config.json --public_url=http://localhost:8080

clean:
	@echo "\033[33m→ Cleaning workspace...\033[0m"
	rm -rf $(TMP)
	rm -f $(OUTPUT)