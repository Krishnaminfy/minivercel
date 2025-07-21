#!/bin/bash

# Utility to add timestamp to logs (optional)
timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_info() {
  echo -e "\033[1;34m[INFO] $(timestamp)\033[0m $1"
}

log_success() {
  echo -e "\033[1;32m[SUCCESS] $(timestamp)\033[0m $1"
}

log_warn() {
  echo -e "\033[1;33m[WARN] $(timestamp)\033[0m $1"
}

log_error() {
  echo -e "\033[1;31m[ERROR] $(timestamp)\033[0m $1"
}
