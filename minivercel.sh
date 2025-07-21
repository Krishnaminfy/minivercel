#!/bin/bash


# Print the main menu
print_menu() {
  echo "============================"
  echo " Welcome to My Vercel"
  echo "============================"
  echo "Choose an option:"
  echo "1. Deploy Application"
  echo "2. Manage Applications"
  echo "3. Exit"
  echo "----------------------------"
}

# Check if an application is deployed (based on state file)
is_app_deployed() {
  [[ -s "$APP_STATE_FILE" ]]
}

# Main loop
while true; do
  print_menu
  read -p "Enter your choice (1/2/3): " choice

  case "$choice" in
    1)
      echo "Starting deployment..."
      if bash vercello.sh; then
        echo "Deployment successful"
        # echo "deployed=true" > "$APP_STATE_FILE"
      else
        echo "Deployment failed. Returning to menu."
      fi
      ;;
    2)
      echo "Choose what to manage:"
      echo "1. S3"
      echo "2. EC2"
      read -p "Enter your choice (1/2): " destroy_choice

      case "$destroy_choice" in
        1)
          bash commands/destroy_s3.sh
          ;;
        2)
          bash commands/destroy_ec2.sh
          ;;
        *)
          echo "Invalid input. Please enter 1 or 2."
          ;;
      esac
      ;;
    3)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid input. Please enter 1, 2, or 3."
      ;;
  esac
  echo ""
done
