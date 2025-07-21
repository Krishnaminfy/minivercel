set -e
source .env.sh
source utils/log.sh

while true; do
  echo ""
  echo -e "\033[1;36m Welcome to Vercello EC2 Application Manager\033[0m"
  echo "What would you like to do?"
  echo "1. Deploy other application"
  echo "2. Destroy ec2  deployment Caution, It will destroy all the applications on the instance"
  echo "3. Exit"
  echo "4. Run cron job to check new commits and Redeploy"
  echo ""
  read -p "Enter your choice: " USER_CHOICE

  case "$USER_CHOICE" in
    1)
      log_info " Triggering new EC2 deployment..."
      bash vercello.sh
      break
      ;;
    2)
    if [ ! -s global_data/ec2_status.txt ]; then
        log_info "No EC2 instance found to destroy."
    else
        if grep -qi "running" global_data/ec2_status.txt; then
        log_info "Destroying EC2 infrastructure..."
        bash utils/terraform_runner.sh destroy
        : > global_data/ec2_status.txt  # Safely clears the file
        log_success "Infrastructure destroyed successfully!"
        else
        log_info "No active EC2 instance state found to destroy."
        fi
    fi
    ;;
    3)
      echo -e "\033[1;34m Exiting Vercello EC2 Manager.\033[0m"
      break
      ;;
    4)
      log_info " Starting cron job for auto-deployment based on new commits..."
      bash commands/cron_ec2.sh
      ;;
   *)
      echo -e "\033[1;31m Invalid option. Please enter 1, 2, or 3.\033[0m"
      ;;
  esac
done