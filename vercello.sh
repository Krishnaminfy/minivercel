#!/bin/bash
set -e

source utils/log.sh
source .env.sh

ENV_FILE=".env.sh"
# echo "#!/bin/bash" > "$ENV_FILE"

log_info " Welcome to Vercello CLI!"
log_info "We'll help you prepare your app for deployment."

# APP_DIR="apps/my-app"
# mkdir -p "$APP_DIR"

APP_DIR="apps/my-app"

if [ -d "$APP_DIR" ] && [ "$(ls -A "$APP_DIR")" ]; then
  log_warn "  $APP_DIR already exists and is not empty. Deleting it..."
  rm -rf "$APP_DIR"
fi

mkdir -p "$APP_DIR"


# Step 1: Get GitHub Repo
read -p " Enter your GitHub repo URL: " REPO_URL
echo "$REPO_URL" > "$APP_DIR/repo.txt"

# log_info " Cloning repo to $APP_DIR/code ..."
# git clone "$REPO_URL" "$APP_DIR/code"
# log_success " Repo cloned successfully."

# Ask for branch name (default: main)
read -p " Enter branch name to deploy (default: main): " BRANCH_NAME
BRANCH_NAME=${BRANCH_NAME:-main}

log_info " Cloning branch '$BRANCH_NAME' to $APP_DIR/code ..."
git clone --branch "$BRANCH_NAME" --single-branch "$REPO_URL" "$APP_DIR/code"
log_success " Repo cloned successfully with branch '$BRANCH_NAME'."


# Step 2: Ask for path inside the repo
echo ""
log_info " Where is your app code located inside the repo?"
echo " Example:"
echo "   - If your code is in root, enter: ."
echo "   - If it's in a folder like 'client', enter: client"
read -p " Enter relative path to code inside repo: " RELATIVE_PATH
if [ "$RELATIVE_PATH" != "." ]; then
  echo "$RELATIVE_PATH" > "$APP_DIR/root_folder_path.txt"
else
  rm -f "$APP_DIR/root_folder_path.txt"  # Ensure it's removed if it exists from earlier
fi

CODE_PATH="$APP_DIR/code/$RELATIVE_PATH"
echo "$CODE_PATH" > "$APP_DIR/code_path.txt"
log_info " Code path set to: $CODE_PATH"

# REPO_NAME=$(basename -s .git "$REPO_URL")
# APP_NAME=${REPO_NAME//[^a-zA-Z0-9]/-}  # sanitize name for S3 (alphanumeric and dashes)
# echo "$APP_NAME" > "$APP_DIR/app_name.txt"

# Get the repo name without .git
REPO_NAME=$(basename -s .git "$REPO_URL")

# # Convert to lowercase and replace invalid characters (_ and others) with hyphens
# APP_NAME=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

# # Optional: Append random 4-digit number to avoid collisions
# APP_NAME="${APP_NAME}-$(date +%s | tail -c 5)"

# Convert repo name to lowercase
BASE_NAME=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

# Normalize branch name too
NORMALIZED_BRANCH=$(echo "$BRANCH_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

TIMESTAMP_SUFFIX=$(date +%s | tail -c 5)
# Create full app name
APP_NAME="${BASE_NAME}-${NORMALIZED_BRANCH}-${TIMESTAMP_SUFFIX}"

echo "$BASE_NAME" > "$APP_DIR/base_app_name.txt"

# Save for later use
echo "$APP_NAME" > "$APP_DIR/app_name.txt"

echo "REPO_URL=$REPO_URL"
echo "BRANCH_NAME=$BRANCH_NAME"
echo "APP_NAME=$APP_NAME"
echo "APP_DIR=$APP_DIR"
echo "CODE_PATH=$CODE_PATH"

cat <<EOF > .env.sh
# Auto-generated
export REPO_URL="$REPO_URL"
export BRANCH_NAME="$BRANCH_NAME"
export BASE_APP_NAME="$BASE_NAME"
export APP_NAME="$APP_NAME"
export APP_DIR="$APP_DIR"
export CODE_PATH="$CODE_PATH"
EOF

log_success "Exported environment variables to .env.sh"




# Step 3: Ask where to deploy (EC2 or S3)
echo ""
log_info "Where would you like to deploy your app?"
echo "1) EC2 (for dynamic apps like Node/React)"
echo "2) S3 (for static sites)"
read -p " Choose your deployment target [1-2]: " DEPLOY_TARGET

case "$DEPLOY_TARGET" in
  1)
    echo "ec2" > "$APP_DIR/deploy_target.txt"
    log_info " EC2 selected. Continuing with setup..."

    # === Check for Pending S3 Buckets ===
    BUCKET_LIST_FILE="global_data/bucket_list.txt"
    if [ -s "$BUCKET_LIST_FILE" ]; then
      echo ""
      log_warn " Found old S3 bucket entries that might need cleanup."
      read -p " Do you want to destroy them now? (y/n): " DESTROY_CHOICE

      if [[ "$DESTROY_CHOICE" == "y" || "$DESTROY_CHOICE" == "Y" ]]; then
        log_info "Select option to Destroy"
        source .env.sh  # Ensure APP_NAME is available
        bash commands/destroy_s3.sh
      else
        log_info "Skipping destroy. Continuing with EC2 setup..."
      fi
    fi

    

    # === EC2 Deployment Flow Begins ===

    # Step 4: Select Tech Stack
    echo ""
    log_info "What tech stack is your project using?"
    echo "1) React"
    echo "2) Node.js"
    echo "3) Python"
    echo "4) Angular"
    read -p "Choose your stack [1-4]: " STACK_CHOICE

    case "$STACK_CHOICE" in
      1) STACK="react" ;;
      2) STACK="node" ;;
      3) STACK="python" ;;
      4) STACK="angular" ;;
      *) log_error "Invalid choice. Exiting." && exit 1 ;;
    esac

    echo "$STACK" > "$APP_DIR/stack.txt"
    log_info "Stack set to: $STACK"

    # Step 5: Ask for App Port
    echo ""
    read -p "What port does your application run on? (e.g., 5173 for Vite, 3000 for Node): " APP_PORT
    echo "$APP_PORT" > "$APP_DIR/port.txt"
    log_info "Application port set to: $APP_PORT"

    # Step 6: Ask for Start Command
    echo ""
    read -p "Enter the start command to run your app (e.g., npm run dev -- --host): " START_CMD
    echo "$START_CMD" > "$APP_DIR/start_command.txt"
    log_info "Start command saved: $START_CMD"

    log_success "EC2 Setup complete!"
    bash commands/init.sh
    echo ""
    # log_info "Now run: bash commands/init.sh to continue with Dockerfile generation & infra setup"
    ;;


  2)
    echo "s3" > "$APP_DIR/deploy_target.txt"
    log_info "S3 selected. Running S3 deployment setup..."
    export AUTO_DESTROY="true"

        # === Check for Pending S3 Buckets ===
    RUNNING_EC2="global_data/ec2_status.txt"
    if [ -s "$RUNNING_EC2" ]; then
      echo ""
      log_warn " Found ec2 instance running."
      read -p " Do you want to destroy them now? (y/n): " DESTROY_CHOICE

      if [[ "$DESTROY_CHOICE" == "y" || "$DESTROY_CHOICE" == "Y" ]]; then
        log_info "Select option to Destroy"
        source .env.sh  # Ensure APP_NAME is available
        bash utils/terraform_runner.sh destroy
        : > global_data/ec2_status.txt
      else
        log_info "Skipping destroy. Continuing with s3 setup..."
      fi
    fi

    APP_NAME=$(cat "$APP_DIR/app_name.txt")

    python commands/detect.py "$CODE_PATH"
    # === Run custom S3 deploy script ===
    FINAL_CODE_PATH=$(cat "$CODE_PATH/final_code_path.txt")
    echo "$FINAL_CODE_PATH" > "$APP_DIR/code_path.txt"
    log_success "Build complete. Final code path set to: $FINAL_CODE_PATH"
    
    bash commands/deploy_s3.sh "$APP_NAME" "$FINAL_CODE_PATH"

    # mkdir -p krish_cli/global_data
    # BUCKET_NAME=$(cat "$APP_DIR/bucket_name.txt")
    # echo "$APP_NAME:$BUCKET_NAME" >> krish_cli/global_data/bucket_list.txt

    # log_success "Stored $APP_NAME:$BUCKET_NAME to bucket_list.txt"

    log_success "S3 deployment complete!"
    exit 0
    ;;


esac
