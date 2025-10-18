# 文件驱动命令执行器

## 🎯 项目概述

基于文件变化监控的命令执行系统，专为喜欢IDE操作的开发者设计。

### 💡 设计初衷

开发者 f14xuanlv 不喜欢终端操作，祂想要的是：

1. **纯IDE体验** - 将命令写在文件里面
2. **自动执行** - 保存文件后自动执行命令
3. **结果输出** - 执行结果输出到日志文件
4. **阅读友好** - 在IDE里查看结果

**工作流程：**
```
编写命令 → 保存文件 → 后台检测 → 自动执行 → 查看结果
```

## 📁 项目文件结构

```
file_monitor_project/
├── config.sh                # 配置文件
├── file_monitor.sh          # 服务管理脚本
├── latest_run.sh           # 示例命令文件
├── claude_editable_run.sh  # Claude命令文件示例
├── README.md               # 本说明文档
├── /mnt/user-data/uploads/  # 用户文件监控目录
│   └── latest_run.sh       # 用户编辑的命令文件
└── /mnt/user-data/outputs/  # 结果输出目录
    ├── claude_editable_run.sh  # Claude编辑的命令文件
    ├── latest_result.log   # 用户命令执行结果
    ├── claude_latest_result.log # Claude命令执行结果
    ├── file-monitor-heartbeat.log # 服务心跳日志
    ├── .file_monitor.pid   # 进程PID文件
    ├── .file_monitor.log   # 服务日志文件
    └── .manual_stop        # 停止标记文件
```

## 🚀 快速开始

### 1. 设置执行权限
```bash
chmod +x config.sh file_monitor.sh
chmod 777 /mnt/
```

### 2. 启动服务
```bash
./file_monitor.sh start
```

### 3. 创建用户文件
```bash
mkdir -p /mnt/user-data/uploads
echo '#!/bin/bash
echo "Hello, this is a test command!"
date' > /mnt/user-data/uploads/latest_run.sh
chmod +x /mnt/user-data/uploads/latest_run.sh
```

### 4. 编辑文件
系统支持双文件监控：
- **用户编辑**: `/mnt/user-data/uploads/latest_run.sh`
- **Claude编辑**: `/mnt/user-data/outputs/claude_editable_run.sh`

### 5. 查看结果
- **用户命令结果**: `/mnt/user-data/outputs/latest_result.log`
- **Claude命令结果**: `/mnt/user-data/outputs/claude_latest_result.log`

## 💡 使用场景

### API接口测试
```bash
curl -s https://api.github.com | jq '.current_user_url'
```

### 系统信息收集
```bash
echo "=== 系统信息 ==="
uname -a
df -h | head -5
free -h
```

### 批量文件操作
```bash
find /tmp -name "*.tmp" -mtime +7 -type f | head -10
```

## 📋 服务管理

```bash
./file_monitor.sh start     # 启动服务
./file_monitor.sh stop      # 停止服务
./file_monitor.sh restart   # 重启服务
./file_monitor.sh status    # 查看状态
./file_monitor.sh reset     # 重置服务状态
./file_monitor.sh help      # 显示帮助
```

## 🔍 故障排查

### 服务未响应
```bash
./file_monitor.sh status    # 检查服务状态
./file_monitor.sh reset     # 重置服务状态
```

### 命令执行失败
```bash
cat /mnt/user-data/uploads/latest_run.sh           # 检查命令文件
bash /mnt/user-data/uploads/latest_run.sh          # 手动测试命令
cat /mnt/user-data/outputs/.file_monitor.log       # 查看日志
```

### 权限问题
```bash
chmod +x file_monitor.sh                           # 修复脚本权限
ls -la /mnt/user-data/                             # 检查目录权限
```

## 🔗 快速参考

### 重要文件路径
- **用户命令编辑**: `/mnt/user-data/uploads/latest_run.sh`
- **Claude命令编辑**: `/mnt/user-data/outputs/claude_editable_run.sh`
- **用户结果查看**: `/mnt/user-data/outputs/latest_result.log`
- **Claude结果查看**: `/mnt/user-data/outputs/claude_latest_result.log`
- **服务日志**: `/mnt/user-data/outputs/.file_monitor.log`
- **心跳日志**: `/mnt/user-data/outputs/file-monitor-heartbeat.log`