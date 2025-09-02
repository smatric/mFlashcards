# mFlashcards Deployment Makefile

# Configuration
SERVER_HOST = root@mflashcards.mcode.dev
SERVER_PATH = /var/www/mFlashcards/
BUILD_DIR = dist

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  build   - Build the application for production"
	@echo "  deploy  - Build and deploy to production server"
	@echo "  clean   - Clean build directory"
	@echo "  ssh     - SSH into the production server"

# Build the application
.PHONY: build
build:
	@echo "Building application for production..."
	npm run build
	@echo "Build complete!"

# Clean build directory
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete!"

# Deploy to production server
.PHONY: deploy
deploy: build
	@echo "Deploying to $(SERVER_HOST)..."
	rsync -avz --delete $(BUILD_DIR)/ $(SERVER_HOST):$(SERVER_PATH)
	@echo "Deployment complete!"
	@echo "Your app should be available at: https://mflashcards.mcode.dev"

# SSH into the production server
.PHONY: ssh
ssh:
	@echo "Connecting to $(SERVER_HOST)..."
	ssh $(SERVER_HOST)