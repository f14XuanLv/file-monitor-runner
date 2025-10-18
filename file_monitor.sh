#!/bin/bash

# File monitoring service manager

# Load unified configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"


# Create daemon process
create_daemon() {
    local daemon_script="/tmp/monitor_daemon_$$.sh"
    cat > "$daemon_script" << 'EOF'
#!/bin/bash

# Dynamically get script directory and configuration
DAEMON_SCRIPT_DIR="SCRIPT_DIR_PLACEHOLDER"
source "$DAEMON_SCRIPT_DIR/config.sh"

# Error handling function
handle_error() {
    local error_msg="$1"
    local exit_code="${2:-1}"

    log_message "Daemon error: $error_msg" "ERROR"

    # If manually stopped, exit normally
    if is_manual_stop; then
        log_message "Manual stop flag detected, exiting daemon" "INFO"
        rm -f "$PID_FILE"
        exit 0
    fi

    # Simple restart (no restart count limit)
    log_message "Preparing to restart, delay 5 seconds" "WARNING"
    sleep 5
    exec "$DAEMON_SCRIPT_DIR/file_monitor.sh" start
}

# Set error traps
trap 'handle_error "Process unexpectedly exited" $?' EXIT
trap 'handle_error "Received interrupt signal" 130' INT
trap 'handle_error "Received termination signal" 143' TERM

# Completely detach from terminal environment (only redirect stdin, keep stdout/stderr for logs)
exec </dev/null

# Write current process PID to file
echo $$ > "$PID_FILE"

# Get initial timestamps
if check_file "$COMMAND_FILE"; then
    LAST_MTIME=$(stat -c %Y "$COMMAND_FILE" 2>/dev/null || echo "0")
else
    LAST_MTIME=0
fi

if check_file "$CLAUDE_COMMAND_FILE"; then
    CLAUDE_LAST_MTIME=$(stat -c %Y "$CLAUDE_COMMAND_FILE" 2>/dev/null || echo "0")
else
    CLAUDE_LAST_MTIME=0
fi

# Record startup log
log_message "File monitoring service started, monitoring: $COMMAND_FILE and $CLAUDE_COMMAND_FILE" "INFO"

# Initialize heartbeat counter
HEARTBEAT_COUNTER=0

# Main monitoring loop
while true; do
    # Check if manual stop signal received
    if is_manual_stop; then
        log_message "Manual stop flag detected, exiting normally" "INFO"
        rm -f "$PID_FILE"
        trap - EXIT  # Remove exit trap
        exit 0
    fi

    # File monitoring logic - Check user-edited file
    EXECUTED=false
    if check_file "$COMMAND_FILE"; then
        CURRENT_MTIME=$(stat -c %Y "$COMMAND_FILE" 2>/dev/null || echo "0")

        if [ "$CURRENT_MTIME" != "$LAST_MTIME" ] && [ "$CURRENT_MTIME" != "0" ]; then
            log_message "User file change detected, executing command" "INFO"

            # Read and execute command
            COMMAND=$(cat "$COMMAND_FILE" 2>/dev/null || echo "echo 'Command file read failed'")

            # Execute command and save result (with error handling)
            {
                printf "===============================================\n"
                printf "🕒 Execution time: %s\n" "$(date)"
                printf "📝 File source: User edited ($COMMAND_FILE)\n"
                printf "📝 Executed command: %s\n" "$COMMAND"
                printf "===============================================\n\n"

                # Execute command
                timeout "$COMMAND_TIMEOUT" bash -c "$COMMAND" 2>&1
                EXIT_CODE=$?

                printf "\n===============================================\n"
                case $EXIT_CODE in
                    0) printf "✅ Execution completed, exit code: %d\n" $EXIT_CODE ;;
                    124) printf "⚠️ Command execution timeout (%d seconds)\n" $COMMAND_TIMEOUT ;;
                    *) printf "❌ Execution failed, exit code: %d\n" $EXIT_CODE ;;
                esac
                printf "===============================================\n"
            } > "$RESULT_FILE" 2>&1

            LAST_MTIME=$CURRENT_MTIME
            EXECUTED=true
        fi
    else
        log_message "User command file does not exist or is not readable: $COMMAND_FILE" "WARNING"
    fi

    # File monitoring logic - Check Claude-edited file
    if check_file "$CLAUDE_COMMAND_FILE"; then
        CLAUDE_CURRENT_MTIME=$(stat -c %Y "$CLAUDE_COMMAND_FILE" 2>/dev/null || echo "0")

        if [ "$CLAUDE_CURRENT_MTIME" != "$CLAUDE_LAST_MTIME" ] && [ "$CLAUDE_CURRENT_MTIME" != "0" ]; then
            log_message "Claude file change detected, executing command" "INFO"

            # Read and execute command
            COMMAND=$(cat "$CLAUDE_COMMAND_FILE" 2>/dev/null || echo "echo 'Claude command file read failed'")

            # Execute command and save result (with error handling)
            {
                printf "===============================================\n"
                printf "🕒 Execution time: %s\n" "$(date)"
                printf "📝 File source: Claude edited ($CLAUDE_COMMAND_FILE)\n"
                printf "📝 Executed command: %s\n" "$COMMAND"
                printf "===============================================\n\n"

                # Execute command
                timeout "$COMMAND_TIMEOUT" bash -c "$COMMAND" 2>&1
                EXIT_CODE=$?

                printf "\n===============================================\n"
                case $EXIT_CODE in
                    0) printf "✅ Execution completed, exit code: %d\n" $EXIT_CODE ;;
                    124) printf "⚠️ Command execution timeout (%d seconds)\n" $COMMAND_TIMEOUT ;;
                    *) printf "❌ Execution failed, exit code: %d\n" $EXIT_CODE ;;
                esac
                printf "===============================================\n"
            } > "$CLAUDE_RESULT_FILE" 2>&1

            CLAUDE_LAST_MTIME=$CLAUDE_CURRENT_MTIME
        fi
    fi

    # Heartbeat check: Output Beijing time every HEARTBEAT_INTERVAL seconds
    HEARTBEAT_COUNTER=$((HEARTBEAT_COUNTER + MONITOR_INTERVAL))
    if [ $HEARTBEAT_COUNTER -ge $HEARTBEAT_INTERVAL ]; then
        # Output Beijing time to the last line of heartbeat log file
        echo "$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S CST')" >> "$HEARTBEAT_LOG"
        HEARTBEAT_COUNTER=0
    fi

    sleep "$MONITOR_INTERVAL"
done
EOF

    # Replace script directory placeholder
    sed -i "s|SCRIPT_DIR_PLACEHOLDER|$SCRIPT_DIR|g" "$daemon_script"

    # Give daemon script execute permissions
    chmod +x "$daemon_script"

    echo "$daemon_script"
}

# Start service
start_service() {
    echo_icon "Starting file monitoring service..." "GEAR"

    if is_service_running; then
        echo_icon "Service is already running (PID: $(get_pid))" "WARNING"
        return 1
    fi

    # Clear manual stop flag
    clear_manual_stop

    # Ensure directories exist and check paths
    if ! ensure_directories || ! check_paths; then
        echo_icon "Environment check failed, cannot start service" "ERROR"
        return 1
    fi

    # Create initial result file
    echo_icon "File monitoring service preparing to start..." "LOADING" > "$RESULT_FILE"

    # Create and start daemon process
    local daemon_script=$(create_daemon)
    setsid "$daemon_script" </dev/null >/dev/null 2>&1 &

    # Wait for PID file generation
    sleep 0.5

    if check_file "$PID_FILE"; then
        local pid=$(get_pid)
        echo_icon "Service started successfully (PID: $pid)" "SUCCESS"
        echo_icon "User file: $COMMAND_FILE" "FILE"
        echo_icon "Claude file: $CLAUDE_COMMAND_FILE" "FILE"
        echo_icon "User result: $RESULT_FILE" "FILE"
        echo_icon "Claude result: $CLAUDE_RESULT_FILE" "FILE"
        echo_icon "Log file: $LOG_FILE" "LOG"

        # Clean up temporary script
        rm -f "$daemon_script"
        return 0
    else
        echo_icon "Service startup failed" "ERROR"
        rm -f "$daemon_script"
        return 1
    fi
}

# Stop service
stop_service() {
    if check_file "$PID_FILE"; then
        echo_icon "Stopping service..." "STOP"

        # Set manual stop flag
        set_manual_stop

        local pid=$(get_pid)
        if is_process_running "$pid"; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo_icon "Service stopped" "SUCCESS"
        else
            rm -f "$PID_FILE"
            echo_icon "Service process no longer exists, cleaning PID file" "WARNING"
        fi
    else
        echo_icon "No running service detected" "INFO"
    fi
}

# Restart service
restart_service() {
    echo_icon "Restarting file monitoring service..." "LOADING"
    stop_service
    sleep 2
    start_service
}

# Reset service status
reset_service() {
    echo_icon "Resetting service status..." "GEAR"

    # Stop service
    stop_service

    # Clean up status files
    rm -f "$STOP_FLAG_FILE"

    echo_icon "Service status reset" "SUCCESS"
}

# View service status
status_service() {
    echo_icon "Service status:" "GEAR"

    if is_service_running; then
        local pid=$(get_pid)
        echo_icon "Service running (PID: $pid)" "SUCCESS"
        echo_icon "User file: $COMMAND_FILE" "FILE"
        echo_icon "Claude file: $CLAUDE_COMMAND_FILE" "FILE"
        echo_icon "User result: $RESULT_FILE" "FILE"
        echo_icon "Claude result: $CLAUDE_RESULT_FILE" "FILE"
        echo_icon "Heartbeat log: $HEARTBEAT_LOG" "FILE"

        # Show stop flag status
        if is_manual_stop; then
            echo_icon "Status: Marked for manual stop" "WARNING"
        else
            echo_icon "Status: Running normally" "SUCCESS"
        fi

        if check_file "$LOG_FILE"; then
            echo_icon "Recent logs:" "LOG"
            tail -5 "$LOG_FILE"
        fi

        if check_file "$HEARTBEAT_LOG"; then
            echo_icon "Recent heartbeats:" "LOG"
            tail -3 "$HEARTBEAT_LOG"
        fi
    else
        echo_icon "Service not running" "ERROR"
        if is_manual_stop; then
            echo_icon "Reason: Manual stop" "INFO"
        fi
    fi
}

# Show help information
show_help() {
    echo_icon "File Monitoring Service Manager" "GEAR"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|reset|help}"
    echo "       or: ./file_monitor.sh {command}"
    echo ""
    echo "Basic commands:"
    echo "  start       - Start service"
    echo "  stop        - Stop service"
    echo "  restart     - Restart service"
    echo "  status      - View service status"
    echo "  reset       - Reset service status"
    echo "  help        - Show this help information"
    echo ""
    echo_icon "Related files:" "FILE"
    printf "  Monitor path: %s\n" "$MONITOR_PATH"
    printf "  User file: %s\n" "$COMMAND_FILE"
    printf "  Claude file: %s\n" "$CLAUDE_COMMAND_FILE"
    printf "  Result path: %s\n" "$RESULT_PATH"
    printf "  User result: %s\n" "$RESULT_FILE"
    printf "  Claude result: %s\n" "$CLAUDE_RESULT_FILE"
    printf "  Log file: %s\n" "$LOG_FILE"
    printf "  Heartbeat log: %s\n" "$HEARTBEAT_LOG"
    echo ""
    echo_icon "Configuration info:" "INFO"
    printf "  Project directory: %s\n" "$PROJECT_DIR"
    printf "  Monitor interval: %d seconds\n" "$MONITOR_INTERVAL"
    printf "  Command timeout: %d seconds\n" "$COMMAND_TIMEOUT"
    printf "  Heartbeat interval: %d seconds\n" "$HEARTBEAT_INTERVAL"
}


# Main logic
case "${1:-start}" in
    "start")
        start_service
        ;;
    "stop")
        stop_service
        ;;
    "restart")
        restart_service
        ;;
    "status")
        status_service
        ;;
    "reset")
        reset_service
        ;;
    "help"|*)
        show_help
        ;;
esac