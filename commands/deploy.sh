#!/bin/bash
set -e
source utils/log.sh
source .env.sh

KEY_PATH=".ssh/testing-key-pair.pem"
#APP_DIR="apps/my-app"
APP_PATH=$(cat "$APP_DIR/code_path.txt")
PORT=$(cat "$APP_DIR/port.txt")
#APP_NAME="my-app"
STATE_FILE="/tmp/last_port_used.txt"

if [ ! -f "$APP_DIR/tag.txt" ]; then
  echo "v1" > "$APP_DIR/tag.txt"
fi

CURRENT_TAG=$(cat "$APP_DIR/tag.txt")
echo "[INFO] Current tag is $CURRENT_TAG"

# TAG_NUM=${CURRENT_TAG#v}

# Increment tag number
# NEXT_TAG_NUM=$((TAG_NUM + 1))
# NEXT_TAG="v$NEXT_TAG_NUM"

# === Step 1: Determine which port to use based on last state ===
if [ -f "$STATE_FILE" ]; then
  LAST_USED=$(cat "$STATE_FILE")
  if [ "$LAST_USED" == "8000" ]; then
    FREE_PORT=8001
    OCCUPIED_PORT=8000
  else
    FREE_PORT=8000
    OCCUPIED_PORT=8001
  fi
else
  FREE_PORT=8000
  OCCUPIED_PORT=8001
fi

# === Step 2: Save current choice for next deployment ===
echo "$FREE_PORT" > "$STATE_FILE"

# === Step 3: Set image tag ===
IMAGE_TAG="${APP_NAME}:${CURRENT_TAG}"

echo " Using port: $FREE_PORT"
echo " Stopping any container on: $OCCUPIED_PORT"
echo " Image tag: $IMAGE_TAG"

# USER_IP=$(curl -s ifconfig.me)
# SSH_CIDR="${USER_IP}/32"
# export SSH_CIDR 

# === Step 1: Launch EC2 ===
bash utils/terraform_runner.sh apply
log_success " EC2 instance launched!"

# === Step 2: Get EC2 IP ===
cd terraform
PUBLIC_IP=$(terraform output -raw public_ip)
cd - > /dev/null

log_info " EC2 Public IP: $PUBLIC_IP"

# === Step 3: Get ECR URL ===
# cd terraform
# ECR_REPO_URI=$(terraform output -raw ecr_repo_uri)
# cd - > /dev/null

# ECR_IMAGE_TAG="$ECR_REPO_URI:$CURRENT_TAG"

log_info "making directory inside ec2"
sleep 5
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" "mkdir -p ~/app"

# === Step 3: Upload app code ===
log_info " Uploading code to EC2..."
scp -i "$KEY_PATH" -r "$APP_PATH"/* ec2-user@"$PUBLIC_IP":~/app

# === Step 4: Install Docker & Reboot === 
log_info "🔧 Installing Docker on EC2..."
ssh -i "$KEY_PATH" ec2-user@"$PUBLIC_IP" << 'EOF'
  set -e
  sudo yum update -y
  sudo yum install -y docker git
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker ec2-user
EOF

# === Step 5: Wait for reboot ===
log_info " Waiting for EC2 to reboot..."
sleep 5

# Ping until ready (optional)
until ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ec2-user@"$PUBLIC_IP" "echo ' EC2 is back online'" &> /dev/null; do
  sleep 5
done

# === Step 6: Build and run docker ===
log_info " Running Docker commands without sudo..."
ssh -i "$KEY_PATH" ec2-user@"$PUBLIC_IP" << EOF
  set -e
  cd ~/app
  echo "🔧 Building Docker image..."
  docker build -t "$IMAGE_TAG" .
  echo " Running container on port $PORT..."
  docker run -d -p $FREE_PORT:$PORT "$IMAGE_TAG"
  echo " Logging in to ECR and pushing image..."
  # aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ECR_REPO_URI"
  # aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 932384979115.dkr.ecr.ap-south-1.amazonaws.com
  # docker tag "$IMAGE_TAG:latest" "$ECR_IMAGE_TAG"
  # docker push "$ECR_IMAGE_TAG"
EOF

# === Step 7: Update tag version locally for next deploy ===
TAG_NUM=${CURRENT_TAG#v}
NEXT_TAG_NUM=$((TAG_NUM + 1))
NEXT_TAG="v$NEXT_TAG_NUM"
echo "$NEXT_TAG" > "$APP_DIR/tag.txt"
echo "[INFO] Updated tag to $NEXT_TAG"

log_success " App deployed successfully at: http://$PUBLIC_IP:$FREE_PORT"

mkdir -p global_data
echo "running" > global_data/ec2_status.txt

# # === Step 8: Handle Multiple Versions ===
# if [ "$TAG_NUM" -ge 1 ]; then
#   log_info " Checking running versions..."

#   ssh -i "$KEY_PATH" ec2-user@"$PUBLIC_IP" << 'EOF'
#     echo " Active Docker containers:"
#     docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Ports}}\t{{.Names}}"

#     echo ""
#     echo "Which version do you want to KEEP running?"
#     echo "Type the IMAGE TAG to stop the other one, or press Enter to skip:"

#     read -r TO_KEEP

#     if [ -n "\$TO_KEEP" ]; then
#       CONTAINERS=\$(docker ps --format '{{.ID}} {{.Image}}' | grep -v \$TO_KEEP | awk '{print \$1}')
#       if [ -n "\$CONTAINERS" ]; then
#         echo " Stopping all containers except: \$TO_KEEP"
#         for id in \$CONTAINERS; do
#           docker stop \$id
#         done
#       else
#         echo " No other containers to stop."
#       fi
#     else
#       echo "  Skipped container cleanup. Both versions still running."
#     fi
# EOF
# fi


# # === Step 8: Handle Multiple Versions ===
# if [ "$TAG_NUM" -ge 1 ]; then
#   log_info " Checking running versions..."

#   ssh -i "$KEY_PATH" ec2-user@"$PUBLIC_IP" << 'EOF'
#     echo " Active Docker containers:"
#     docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}"

#     echo ""
#     echo " Available image tags:"
#     TAGS=\$(docker ps --format "{{.Image}}" | sed 's/.*://')
#     echo "\$TAGS" | sort -u | nl

#     echo ""
#     echo "Which image tag do you want to KEEP running (e.g., v1, v2)?"
#     echo "Containers with other tags will be stopped."

#     read -r TO_KEEP

#     if [ -z "\$TO_KEEP" ]; then
#       echo "⏭  No tag entered. Skipping cleanup."
#     else
#       echo " Stopping containers with tags NOT matching '\$TO_KEEP'..."
#       CONTAINERS_TO_STOP=\$(docker ps --format "{{.ID}} {{.Image}}" | grep -v ":\$TO_KEEP" | awk '{print \$1}')

#       if [ -n "\$CONTAINERS_TO_STOP" ]; then
#         docker stop \$CONTAINERS_TO_STOP
#         docker rm \$CONTAINERS_TO_STOP
#         echo " Removed old containers."
#       else
#         echo "ℹ  No containers found with tags other than '\$TO_KEEP'."
#       fi
#     fi
# EOF
# fi


# === Post-Deployment Menu ===
# while true; do
#   echo ""
#   echo -e "\033[1;36m Welcome to Vercello EC2 Application Manager\033[0m"
#   echo "What would you like to do?"
#   echo "1. Deploy other application"
#   echo "2. Destroy ec2  deployment"
#   echo "3. Exit"
#   echo "4. Run cron job to check new commits and Redeploy"
#   echo ""
#   read -p "Enter your choice (1, 2 or 3): " USER_CHOICE

#   case "$USER_CHOICE" in
#     1)
#       log_info " Triggering new EC2 deployment..."
#       bash vercello.sh
#       break
#       ;;
#     2)
#       log_info " Destroying EC2 infrastructure..."
#       bash utils/terraform_runner.sh destroy
#       : > global_data/ec2_status.txt  # Safely clears the file
#       log_success " Infrastructure destroyed successfully!"
#       ;;
#     3)
#       echo -e "\033[1;34m Exiting Vercello EC2 Manager.\033[0m"
#       break
#       ;;
#     4)
#       log_info " Starting cron job for auto-deployment based on new commits..."
#       bash commands/cron_ec2.sh
#       ;;
#    *)
#       echo -e "\033[1;31m Invalid option. Please enter 1, 2, or 3.\033[0m"
#       ;;
#   esac
# done


