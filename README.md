# File-Driven Command Executor

## 🎯 Project Overview

A file change monitoring-based command execution system designed for developers who prefer IDE operations.

### 💡 Design Purpose

Developer f14xuanlv doesn't like terminal operations, he wants:

1. **Pure IDE Experience** - Write commands in files
2. **Auto Execution** - Commands execute automatically after saving files
3. **Result Output** - Execution results output to log files
4. **Reading Friendly** - View results in IDE

**Workflow:**
```
Write Commands → Save File → Background Detection → Auto Execute → View Results
```

## 📁 Project File Structure

```
file_monitor_project/
├── config.sh                # Configuration file
├── file_monitor.sh          # Service management script
├── latest_run.sh           # Sample command file
├── claude_editable_run.sh  # Claude command file example
├── README.md               # This documentation
├── /mnt/user-data/uploads/  # User file monitoring directory
│   └── latest_run.sh       # User-edited command file
└── /mnt/user-data/outputs/  # Result output directory
    ├── claude_editable_run.sh  # Claude-edited command file
    ├── latest_result.log   # User command execution results
    ├── claude_latest_result.log # Claude command execution results
    ├── file-monitor-heartbeat.log # Service heartbeat log
    ├── .file_monitor.pid   # Process PID file
    ├── .file_monitor.log   # Service log file
    └── .manual_stop        # Stop marker file
```

## 🚀 Quick Start

### 1. Set Execution Permissions
```bash
chmod +x config.sh file_monitor.sh
chmod 777 /mnt/
```

### 2. Start Service
```bash
./file_monitor.sh start
```

### 3. Create User File
```bash
mkdir -p /mnt/user-data/uploads
echo '#!/bin/bash
echo "Hello, this is a test command!"
date' > /mnt/user-data/uploads/latest_run.sh
chmod +x /mnt/user-data/uploads/latest_run.sh
```

### 4. Edit Files
The system supports dual file monitoring:
- **User Editing**: `/mnt/user-data/uploads/latest_run.sh`
- **Claude Editing**: `/mnt/user-data/outputs/claude_editable_run.sh`

### 5. View Results
- **User Command Results**: `/mnt/user-data/outputs/latest_result.log`
- **Claude Command Results**: `/mnt/user-data/outputs/claude_latest_result.log`

## 💡 Use Cases

### API Interface Testing
```bash
curl -s https://api.github.com | jq '.current_user_url'
```

### System Information Collection
```bash
echo "=== System Information ==="
uname -a
df -h | head -5
free -h
```

### Batch File Operations
```bash
find /tmp -name "*.tmp" -mtime +7 -type f | head -10
```

## 📋 Service Management

```bash
./file_monitor.sh start     # Start service
./file_monitor.sh stop      # Stop service
./file_monitor.sh restart   # Restart service
./file_monitor.sh status    # View status
./file_monitor.sh reset     # Reset service status
./file_monitor.sh help      # Show help
```

## 🔍 Troubleshooting

### Service Not Responding
```bash
./file_monitor.sh status    # Check service status
./file_monitor.sh reset     # Reset service status
```

### Command Execution Failed
```bash
cat /mnt/user-data/uploads/latest_run.sh           # Check command file
bash /mnt/user-data/uploads/latest_run.sh          # Test command manually
cat /mnt/user-data/outputs/.file_monitor.log       # View logs
```

### Permission Issues
```bash
chmod +x file_monitor.sh                           # Fix script permissions
ls -la /mnt/user-data/                             # Check directory permissions
```

## 🔗 Quick Reference

### Important File Paths
- **User Command Editing**: `/mnt/user-data/uploads/latest_run.sh`
- **Claude Command Editing**: `/mnt/user-data/outputs/claude_editable_run.sh`
- **User Result Viewing**: `/mnt/user-data/outputs/latest_result.log`
- **Claude Result Viewing**: `/mnt/user-data/outputs/claude_latest_result.log`
- **Service Log**: `/mnt/user-data/outputs/.file_monitor.log`
- **Heartbeat Log**: `/mnt/user-data/outputs/file-monitor-heartbeat.log`