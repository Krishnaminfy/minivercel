source .env.sh


GLOBAL_BUCKET_LIST="global_data/bucket_list.txt"
# mkdir -p "$(dirname "$GLOBAL_BUCKET_LIST")"  # Ensure folder exists

# # Save bucket name to global bucket list if not already present
# if ! grep -qxF "$APP_NAME" "$GLOBAL_BUCKET_LIST" 2>/dev/null; then
#   echo "$APP_NAME" >> "$GLOBAL_BUCKET_LIST"
# fi

while true; do
  echo -e "\n Welcome to S3 Application Manager"
  echo "What would you like to do?"
  echo "1. Deploy another application"
  echo "2. Destroy an existing deployment"
  echo "3. Exit"
  echo "4. CI/CD"
  read -p "Enter your choice: " ACTION

  case "$ACTION" in
    1)
      echo "🚀 Triggering deployment..."
      AUTO_DESTROY=true bash vercello.sh  # Change if your deploy script has a different name
      ;;
    2)
      if [[ ! -f "$GLOBAL_BUCKET_LIST" || ! -s "$GLOBAL_BUCKET_LIST" ]]; then
        echo "  No active deployments found to destroy."
        continue
      fi

      echo -e "\n  These are your active Vercello deployments:"
      nl "$GLOBAL_BUCKET_LIST"

      read -p "Enter the number of the application you want to destroy: " CHOICE

      TOTAL_LINES=$(wc -l < "$GLOBAL_BUCKET_LIST")
      if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > TOTAL_LINES )); then
        echo " Invalid selection. Please enter a number between 1 and $TOTAL_LINES."
        continue
      fi

      BUCKET_NAME=$(sed -n "${CHOICE}p" "$GLOBAL_BUCKET_LIST")

      echo -e "\n  You are about to destroy application: \033[1;31m$BUCKET_NAME\033[0m"
      read -p "Are you sure? (yes/no): " CONFIRM

      if [[ "$CONFIRM" != "yes" ]]; then
        echo " Destruction cancelled."
        continue
      fi

      echo " Emptying bucket: s3://$BUCKET_NAME..."
      aws s3 rm "s3://$BUCKET_NAME" --recursive || echo "⚠️ Warning: Could not empty bucket."

      echo " Removing bucket: $BUCKET_NAME..."
      aws s3 rb "s3://$BUCKET_NAME" || echo "⚠️ Warning: Could not remove bucket."

      # Update global list
      grep -vxF "$BUCKET_NAME" "$GLOBAL_BUCKET_LIST" > "${GLOBAL_BUCKET_LIST}.tmp"
      mv "${GLOBAL_BUCKET_LIST}.tmp" "$GLOBAL_BUCKET_LIST"

      echo -e "\n Successfully destroyed and removed: \033[1;32m$BUCKET_NAME\033[0m"
      ;;
    3)
      echo " Exiting Vercello Application Manager."
      exit 0
      ;;
    4)
      echo "running cron job."
      AUTO_DESTROY=false bash commands/cron_s3.sh  
      ;;
    *)
      echo " Invalid option. Please enter 1, 2, or 3."
      ;;
  esac
done
