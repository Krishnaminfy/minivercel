#!/bin/bash
set -e

source utils/log.sh
source .env.sh

log_info "Starting S3 deployment flow..."

# Safety check
if [[ -z "$APP_NAME" || -z "$CODE_PATH" ]]; then
  log_error "Required environment variables are missing. Please check .env.sh"
  exit 1
fi

# === Detect build output (e.g., dist, build)
python commands/detect.py "$CODE_PATH"

FINAL_CODE_PATH=$(cat "$CODE_PATH/final_code_path.txt")
echo "$FINAL_CODE_PATH" > "$APP_DIR/code_path.txt"

log_success "Build detection complete."
log_info "Final static build path: $FINAL_CODE_PATH"

# === Deploy to S3
bash commands/deploy_s3.sh "$APP_NAME" "$FINAL_CODE_PATH"

log_success "S3 deployment finished for $APP_NAME"
