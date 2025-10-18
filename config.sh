#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_PATH="/mnt/user-data/uploads"
RESULT_PATH="/mnt/user-data/outputs"

COMMAND_FILE="${MONITOR_PATH}/latest_run.sh"
CLAUDE_COMMAND_FILE="${RESULT_PATH}/claude_editable_run.sh"
RESULT_FILE="${RESULT_PATH}/latest_result.log"
CLAUDE_RESULT_FILE="${RESULT_PATH}/claude_latest_result.log"
PID_FILE="${RESULT_PATH}/.file_monitor.pid"
LOG_FILE="${RESULT_PATH}/.file_monitor.log"
HEARTBEAT_LOG="${RESULT_PATH}/file-monitor-heartbeat.log"
STOP_FLAG_FILE="${RESULT_PATH}/.manual_stop"
RESTART_COUNT_FILE="${RESULT_PATH}/.restart_count"
LAST_RESTART_FILE="${RESULT_PATH}/.last_restart"

MONITOR_INTERVAL=1
COMMAND_TIMEOUT=30
HEARTBEAT_INTERVAL=10

declare -A ICONS=(
    ["SUCCESS"]="✅"
    ["ERROR"]="❌"
    ["WARNING"]="⚠️"
    ["INFO"]="ℹ️"
    ["LOADING"]="🔄"
    ["STOP"]="🛑"
    ["FILE"]="📝"
    ["LOG"]="📋"
    ["GEAR"]="🔧"
)

echo_icon() {
    local message="$1"
    local icon_type="$2"
    echo "${ICONS[$icon_type]} ${message}"
}

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

check_file() {
    local file="$1"
    [ -f "$file" ] && [ -r "$file" ]
}

is_process_running() {
    local pid="$1"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

get_pid() {
    if check_file "$PID_FILE"; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

is_service_running() {
    local pid=$(get_pid)
    is_process_running "$pid"
}

ensure_directories() {
    if ! mkdir -p "$RESULT_PATH" 2>/dev/null; then
        echo_icon "Unable to create output directory, may lack permissions" "ERROR"
        return 1
    fi


    return 0
}

check_paths() {
    local errors=0

    if [ ! -d "$MONITOR_PATH" ]; then
        echo_icon "Monitor path does not exist: $MONITOR_PATH" "WARNING"
        echo_icon "Please manually create: mkdir -p $MONITOR_PATH" "INFO"
        echo_icon "Service will continue to start, waiting for user to create files" "INFO"
    fi

    if [ ! -d "$RESULT_PATH" ] || [ ! -w "$RESULT_PATH" ]; then
        echo_icon "Result path not accessible: $RESULT_PATH" "ERROR"
        ((errors++))
    fi

    return $errors
}

set_manual_stop() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$STOP_FLAG_FILE"
    log_message "Set manual stop flag" "INFO"
}

clear_manual_stop() {
    rm -f "$STOP_FLAG_FILE"
    log_message "Clear manual stop flag" "INFO"
}

is_manual_stop() {
    [ -f "$STOP_FLAG_FILE" ]
}