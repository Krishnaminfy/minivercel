#!/bin/bash
set -e
source utils/log.sh
source .env.sh

# === 1. Create or reset .env.sh file ===
ENV_FILE=".env.sh"
# echo "#!/bin/bash" > "$ENV_FILE"

#APP_DIR="apps/my-app"
# if [ ! -f "$APP_DIR/tag.txt" ]; then
#   echo "v1" > "$APP_DIR/tag.txt"
# fi


# === 2. Instance & security group name ===
#NAMES=("krishna-app" "livanshu-app" "syed-app" "priyesh-app" "abhishek-app" "akhilesh-app" "nithin-app")
INSTANCE_NAME="krishna-app"
SG_NAME="$INSTANCE_NAME-sg"
AWS_REGION="ap-south-1"

echo "export INSTANCE_NAME=\"$INSTANCE_NAME\"" >> "$ENV_FILE"
echo "export SG_NAME=\"$SG_NAME\"" >> "$ENV_FILE"
echo "export AWS_REGION=\"$AWS_REGION\"" >> "$ENV_FILE"

# === 3. Read app details ===
APP_PATH=$(cat "$APP_DIR/code_path.txt")
echo "export APP_PATH=\"$APP_PATH\"" >> "$ENV_FILE"

# === 5. Generate image details ===
REPO_URL=$(cat "$APP_DIR/repo.txt")
REPO_NAME=$(basename "$REPO_URL" .git)
#IMAGE_NAME="krishnaauto/$REPO_NAME"
#TAG=$(date +%s)
PORT=$(cat "$APP_DIR/port.txt")
USER_IP=$(curl -s ifconfig.me)
SSH_CIDR="${USER_IP}/32"
export SSH_CIDR 

echo "export REPO_URL=\"$REPO_URL\"" >> "$ENV_FILE"
echo "export REPO_NAME=\"$REPO_NAME\"" >> "$ENV_FILE"
#echo "export IMAGE_NAME=\"$IMAGE_NAME\"" >> "$ENV_FILE"
#echo "export TAG=\"$TAG\"" >> "$ENV_FILE"
echo "export PORT=\"$PORT\"" >> "$ENV_FILE"
echo "export SSH_CIDR=\"$SSH_CIDR\"" >> "$ENV_FILE"

# Export for current shell as well
export INSTANCE_NAME SG_NAME APP_PATH REPO_URL REPO_NAME IMAGE_NAME TAG PORT

# === 6. Permission for .env.sh ===
chmod 644 "$ENV_FILE"

# bash utils/terraform_runner.sh destroy

# === 7. Trigger deploy ===
echo ""
log_info " Run: bash commands/deploy.sh to deploy."
bash commands/deploy.sh
