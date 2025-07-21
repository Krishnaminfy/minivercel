#!/bin/bash
set -e
source utils/log.sh

APP_NAME="$1"
CODE_PATH="$2"

log_info "🔧 Setting up S3 infrastructure and uploading files..."

S3_URL=$(python commands/s3_setup.py "$APP_NAME" "$CODE_PATH")

log_success " Files uploaded successfully!"
echo ""
log_info " Your static site is live at:"
echo "$S3_URL"

echo "export APP_NAME=\"$APP_NAME\"" >> .env.sh

# bash commands/destroy_s3.sh "$APP_NAME"
# if [[ "$AUTO_DESTROY" == "true" ]]; then
#   bash commands/destroy_s3.sh "$APP_NAME"
# fi

GLOBAL_BUCKET_LIST="global_data/bucket_list.txt"
mkdir -p "$(dirname "$GLOBAL_BUCKET_LIST")"  # Ensure folder exists

# Save bucket name to global bucket list if not already present
if ! grep -qxF "$APP_NAME" "$GLOBAL_BUCKET_LIST" 2>/dev/null; then
  echo "$APP_NAME" >> "$GLOBAL_BUCKET_LIST"
fi
