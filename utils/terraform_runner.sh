#!/bin/bash
set -e
source utils/log.sh
source .env.sh

cd terraform

COMMAND=$1  # init / apply / destroy etc.

case "$COMMAND" in
  init)
    terraform init -input=false
    ;;
  apply)
    terraform init -input=false
    terraform apply \
      -var="instance_name=$INSTANCE_NAME" \
      -var="security_group_name=$SG_NAME" \
      -var="docker_image=$IMAGE_NAME:$TAG" \
      -var="allowed_ssh_ip=$SSH_CIDR" \
      -auto-approve

    # EC2_PUBLIC_IP=$(terraform output -raw public_ip)
    # log_info "🌐 EC2 Public IP: $EC2_PUBLIC_IP"
    ;;
  destroy)
    terraform init -input=false
    terraform destroy \
      -var="allowed_ssh_ip=$SSH_CIDR" \
      -var="instance_name=$INSTANCE_NAME" \
      -var="security_group_name=$SG_NAME" \
      -var="docker_image=$IMAGE_NAME:$TAG" \
      -auto-approve
    ;;
  *)
    log_error "❌ Unknown command: $COMMAND"
    exit 1
    ;;
esac

cd -
