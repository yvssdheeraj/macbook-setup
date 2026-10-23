#!/usr/bin/env bash

log_info() { printf '[INFO] %s\n' "$*" >&2; }
log_success() { printf '[SUCCESS] %s\n' "$*" >&2; }
log_warn() { printf '[WARNING] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
fatal() { log_error "$*"; exit 1; }
