.PHONY: help clean deploy

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

clean: ## Remove built files
	rm -rf out project/web/assets project/web/*.js

web: project/web/jool-loop.js ## build for web (in project/web/)

start: web ## run a watching/reloading web-server
	@trap 'kill $$(jobs -p) 2>/dev/null || true' INT TERM; \
	npx -y live-server project/web/ & \
	npx -y onchange 'src/*.hx' -- make web & \
	wait


deploy: web ## publish to web
	rm -rf .deploy && cp -r project/web .deploy && rm -f .deploy/.gitignore
	@# Surge doesn't serve .vert/.frag files - rename to .txt and patch JS references
	@for f in .deploy/assets/*.vert .deploy/assets/*.frag; do \
		[ -f "$$f" ] && mv "$$f" "$$f.txt"; \
	done
	@sed -i '' 's/\.vert"/.vert.txt"/g; s/\.frag"/.frag.txt"/g' .deploy/jool-loop.js
	npx -y surge@latest .deploy joolloop.surge.sh
	rm -rf .deploy

# internal targets

project/web/jool-loop.js: src/*.hx
	ceramic clay build web --setup --assets

