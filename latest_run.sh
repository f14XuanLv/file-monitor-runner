#!/bin/bash
# Sample user command file (for reference only)
# This file will not be automatically copied, users need to manually create /mnt/user-data/uploads/latest_run.sh

echo "🎯 Testing file monitoring system functionality"
echo "📅 Current time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "👤 Executing user: $(whoami)"
echo "📍 Working directory: $(pwd)"

echo ""
echo "🔍 System information:"
echo "  Operating system: $(uname -s)"
echo "  Architecture: $(uname -m)"
echo "  Kernel version: $(uname -r)"

echo ""
echo "📊 Process statistics:"
echo "  Current processes: $(ps aux | wc -l)"
echo "  Monitor service: $(ps aux | grep -c file_monitor || echo '0')"

echo ""
echo "✅ Test completed! System running normally."
echo "🔄 Test time: $(date '+%H:%M:%S')"
echo "🆔 Command execution process PID: $$"