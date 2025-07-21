#!/bin/bash
set -e

source utils/log.sh
source .env.sh

log_info "Starting EC2 deployment flow..."

# Safety check
if [[ -z "$APP_NAME" || -z "$CODE_PATH" ]]; then
  log_error "Required environment variables are missing. Please check .env.sh"
  exit 1
fi

STACK_FILE="$APP_DIR/stack.txt"
PORT_FILE="$APP_DIR/port.txt"
CMD_FILE="$APP_DIR/start_command.txt"

# === Prompt fallback if missing
if [[ ! -f "$STACK_FILE" ]]; then
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
    *) log_error "Invalid stack choice. Exiting." && exit 1 ;;
  esac

  echo "$STACK" > "$STACK_FILE"
else
  STACK=$(cat "$STACK_FILE")
fi

if [[ ! -f "$PORT_FILE" ]]; then
  echo ""
  read -p "What port does your application run on? (e.g., 5173 for Vite, 3000 for Node): " PORT
  echo "$PORT" > "$PORT_FILE"
else
  PORT=$(cat "$PORT_FILE")
fi

if [[ ! -f "$CMD_FILE" ]]; then
  echo ""
  read -p "Enter the start command to run your app (e.g., npm run dev -- --host): " START_CMD
  echo "$START_CMD" > "$CMD_FILE"
else
  START_CMD=$(cat "$CMD_FILE")
fi

log_info "Using stack: $STACK"
log_info "App runs on port: $PORT"
log_info "Start command: $START_CMD"

# === Proceed to init
bash commands/init.sh
