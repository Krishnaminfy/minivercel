#!/bin/bash
set -e


APP_DIR="apps/my-app"
APP_PATH=$(cat "$APP_DIR/code_path.txt")
STACK=$(cat "$APP_DIR/stack.txt")
TEMPLATE_DIR="./templates"
DOCKERFILE_PATH="$APP_PATH/Dockerfile"

PORT=$1
START_COMMAND=$2

if [[ -z "$PORT" || -z "$START_COMMAND" ]]; then
  log_error " PORT or START_COMMAND is missing. Make sure 'port.txt' and 'start_command.txt' are correctly filled."
  exit 1
fi


echo "[INFO]   Generating Dockerfile for stack: $STACK"
echo "[INFO]  App path: $APP_PATH"
echo "[INFO]  Port: $PORT"
echo "[INFO]  Start command: $START_COMMAND"


# Template selection based on stack
case "$STACK" in
  react)   TEMPLATE_FILE="Dockerfile.react" ;;
  node)    TEMPLATE_FILE="Dockerfile.node" ;;
  python)  TEMPLATE_FILE="Dockerfile.python" ;;
  angular) TEMPLATE_FILE="Dockerfile.angular" ;;
  *)
    echo "[ERROR]  Unknown stack. Cannot generate Dockerfile."
    exit 1
    ;;
esac

# Read template and replace placeholders
TEMPLATE_CONTENT=$(<"$TEMPLATE_DIR/$TEMPLATE_FILE")
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{PORT\}\}/$PORT}"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{START_COMMAND\}\}/$START_COMMAND}"

# Save the Dockerfile
echo "$TEMPLATE_CONTENT" > "$DOCKERFILE_PATH"

echo "[SUCCESS]  Dockerfile for $STACK generated at $DOCKERFILE_PATH"