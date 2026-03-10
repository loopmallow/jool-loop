.PHONY: help clean run start web windows mac linux

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m

# Default target shows help
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(BLUE)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

clean: ## Delete all built files
	@rm -rf dist

web: dist/web/game.js ## build for web (in dist/web)
	@cp src/index.html dist/web/
	@$(MAKE) --no-print-directory deploy-packs-web

# Copy all packs/ subdirectories to dist/web/packs/ and write manifest.txt
deploy-packs-web:
	@mkdir -p dist/web/packs
	@for pack in packs/*/; do \
		name=$$(basename $$pack); \
		cp -r $$pack dist/web/packs/$$name; \
	done
	@ls packs/ | grep -v README.md > dist/web/packs/manifest.txt
	@echo "$(GREEN)Deployed packs: $$(cat dist/web/packs/manifest.txt | tr '\n' ' ')$(NC)"

run: dist/joolloop_sdl.hl
	hl dist/joolloop_sdl.hl

start: web ## start local server and watch for changes
	@trap 'kill $$(jobs -p) 2>/dev/null || true' INT TERM; \
	npx -y live-server dist/web & \
	npx -y onchange 'src/*.hx' -- make web & \
	wait

mac: dist/mac/joolloop

# internal build targets

HL_HOME    := /opt/homebrew/Cellar/hashlink/1.15_1
HL_INC     := $(HL_HOME)/include
HL_LIB     := $(HL_HOME)/lib
HLSDL      := $(shell haxelib path hlsdl | head -1)

dist/mac/joolloop: src/*.hx
	@mkdir -p dist/mac/src
	@haxe cfg/mac.hxml
	@clang -O2 -std=c11 \
		-I dist/mac/src \
		-I $(HL_INC) \
		-I $(HLSDL) \
		-I /opt/homebrew/include \
		-DGL_SILENCE_DEPRECATION \
		$(HLSDL)/sdl.c $(HLSDL)/gl.c \
		dist/mac/src/main.c \
		-L $(HL_LIB) -lhl \
		$(HL_LIB)/fmt.hdll $(HL_LIB)/ui.hdll $(HL_LIB)/uv.hdll \
		-L /opt/homebrew/lib -lSDL2 -luv \
		-framework OpenGL -framework CoreFoundation \
		-rpath @executable_path \
		-o dist/mac/joolloop
	@echo "$(GREEN)Built dist/mac/joolloop$(NC)"

dist/web/game.js: src/*.hx
	@haxe cfg/web.hxml

dist/joolloop_sdl.hl: src/*.hx
	@haxe cfg/hashlink_sdl.hxml

dist/joolloop_dx.hl: src/*.hx
	@haxe cfg/hashlink_dx.hxml

dist/joolloop_dx12.hl: src/*.hx
	@haxe cfg/hashlink_dx12.hxml

