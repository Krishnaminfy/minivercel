#!/bin/bash
set -e

# trap 'echo " CI/CD script terminated. Exiting..."' EXIT

source .env.sh
source utils/log.sh

# FLAG_FILE="/tmp/stop_watcher"
# rm -f "$FLAG_FILE"

echo "Cron job watcher started."
echo " Type 'stop' and press Enter anytime to stop the job and return to the menu."

# === Validate required variables ===
if [ -z "$REPO_URL" ] || [ -z "$BRANCH_NAME" ] || [ -z "$APP_NAME" ] || [ -z "$CODE_PATH" ]; then
  echo " .env.sh is missing required variables (REPO_URL, BRANCH_NAME, APP_NAME, CODE_PATH)"
  exit 1
fi

echo "[DEBUG] Using REPO_URL=$REPO_URL | BRANCH_NAME=$BRANCH_NAME | APP_NAME=$APP_NAME"

mkdir -p global_data
HISTORY_FILE="global_data/commit_history.txt"
touch "$HISTORY_FILE"

LAST_COMMIT=""
BUCKET_NAME="$APP_NAME"
CLONE_DIR="global_data/s3_deploy_repo"

echo " Watching $REPO_URL [$BRANCH_NAME] for new commits..."
echo " Target S3 Bucket: $BUCKET_NAME"
echo " Code Path: $CODE_PATH"
#echo " Press Ctrl+C to stop."
run_git_cron_loop() {
  while true; do
    LATEST_COMMIT=$(git ls-remote "$REPO_URL" "refs/heads/$BRANCH_NAME" 2>/dev/null | awk '{print $1}')

    if [ -z "$LATEST_COMMIT" ]; then
      echo "$(date) |  Could not fetch latest commit. Skipping..."
      sleep 60
      continue
    fi

    if [ -z "$LAST_COMMIT" ]; then
      LAST_COMMIT=$LATEST_COMMIT
      echo "$(date) | Initial commit: $LATEST_COMMIT" >> "$HISTORY_FILE"
    elif [ "$LATEST_COMMIT" != "$LAST_COMMIT" ]; then
      echo "$(date) |  New commit detected!"
      echo "Old: $LAST_COMMIT" >> "$HISTORY_FILE"
      echo "New: $LATEST_COMMIT" >> "$HISTORY_FILE"

      # === Clone the repository ===
      log_info " Cloning repo: $REPO_URL (branch: $BRANCH_NAME)..."

      if [ -d "$CLONE_DIR" ]; then
      log_warn "Removing existing clone directory: $CLONE_DIR"
      rm -rf "$CLONE_DIR"
      fi

      git clone --depth 1 --branch "$BRANCH_NAME" "$REPO_URL" "$CLONE_DIR"
      log_success " Repo cloned."

      # === Determine correct code path ===
      ROOT_FOLDER_PATH_FILE="$APP_DIR/root_folder_path.txt"

      if [ -s "$ROOT_FOLDER_PATH_FILE" ]; then
      RELATIVE_CODE_PATH=$(cat "$ROOT_FOLDER_PATH_FILE")
      CODE_FULL_PATH="$CLONE_DIR/$RELATIVE_CODE_PATH"
      log_info " Using custom code path from root_folder_path.txt: $RELATIVE_CODE_PATH"
      else
      CODE_FULL_PATH="$CLONE_DIR"
      log_warn " root_folder_path.txt not found or empty. Using default path: $CLONE_DIR"
      fi

      log_info " Checking project in: $CODE_FULL_PATH"

      # === Detect final static build path ===
      python commands/detect.py "$CODE_FULL_PATH" "$AUTO_DESTROY"

      FINAL_CODE_PATH=$(cat "$CODE_FULL_PATH/final_code_path.txt")
      echo "$FINAL_CODE_PATH" > "$CLONE_DIR/code_path.txt"

      # === Empty bucket ===
      echo " Emptying S3 bucket: $BUCKET_NAME"
      aws s3 rm "s3://$BUCKET_NAME" --recursive

      # === Deploy to S3 ===
      echo " Deploying updated code to bucket: $BUCKET_NAME"
      bash commands/deploy_s3.sh "$BUCKET_NAME" "$FINAL_CODE_PATH"

      echo " Deployment complete: https://$BUCKET_NAME.s3.amazonaws.com/"
      echo >> "$HISTORY_FILE"
      echo " CI/CD continues... type 'stop' to stop the watcher and return to the menu."


      # === Update last commit tracker ===
      LAST_COMMIT=$LATEST_COMMIT
    else
      echo "$(date) | No new commit" >> "$HISTORY_FILE"
    fi

    sleep 60
    continue
  done
}

run_git_cron_loop &
CRON_PID=$!

while true; do
  read -p " Watching for changes... (type 'stop' to exit): " input
  if [[ "$input" == "stop" ]]; then
    echo " Stop command received. Exiting watcher..."
    kill "$CRON_PID"
    wait "$CRON_PID" 2>/dev/null
    break
  fi
done


