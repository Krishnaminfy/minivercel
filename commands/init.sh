#!/bin/bash
set -e
source utils/log.sh

APP_DIR="apps/my-app"
APP_PATH=$(cat "$APP_DIR/code_path.txt")
STACK=$(cat "$APP_DIR/stack.txt")
PORT=$(cat "$APP_DIR/port.txt")
START_COMMAND=$(cat "$APP_DIR/start_command.txt")

log_info "  Generating Dockerfile for stack: $STACK"
log_info " App path: $APP_PATH"

# === Step 1: Generate Dockerfile ===
bash commands/generate_dockerfile.sh "$PORT" "$START_COMMAND"

log_success " Dockerfile generated and saved to $APP_PATH/Dockerfile"

echo ""
log_info " Next Step: Setting Infra to EC2"
log_info " Running: setup_infra"

bash commands/setup_infra.sh
