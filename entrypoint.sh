#!/bin/bash

# --- 1. 配置路径 ---
SSL_WATCH_DIR="/app/ssl"
SSL_DEST_DIR="/etc/nginx/certs"
TEMP_DIR="/tmp/ssl_extract"

mkdir -p "$SSL_DEST_DIR"
mkdir -p "$TEMP_DIR"

# --- 2. 核心函数: 生成自签名证书 (兜底) ---
generate_dummy_cert() {
    if [ ! -f "$SSL_DEST_DIR/server.crt" ]; then
        echo "未检测到证书，生成临时自签名证书..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DEST_DIR/server.key" \
            -out "$SSL_DEST_DIR/server.crt" \
            -subj "/C=CN/CN=localhost" 2>/dev/null
    fi
}

# --- 3. 核心函数: 安全重载 ---
reload_nginx() {
    # 检查 Nginx PID 是否存在，如果存在才重载
    if [ -f /var/run/nginx.pid ]; then
        echo "正在重载 Nginx..."
        nginx -s reload
    else
        echo "Nginx 尚未完全启动，跳过本次重载 (证书将在启动时自动加载)"
    fi
}

# --- 4. 核心函数: 处理 ZIP ---
process_ssl_zip() {
    local zip_file="$1"
    echo "发现证书包: $zip_file"
    rm -rf "$TEMP_DIR"/*
    
    # 解压
    unzip -j -o "$zip_file" -d "$TEMP_DIR" > /dev/null 2>&1
    
    # 查找 crt 和 key
    crt_file=$(find "$TEMP_DIR" -maxdepth 1 -name "*.crt" | head -n 1)
    key_file=$(find "$TEMP_DIR" -maxdepth 1 -name "*.key" | head -n 1)

    if [[ -n "$crt_file" && -n "$key_file" ]]; then
        mv "$crt_file" "$SSL_DEST_DIR/server.crt"
        mv "$key_file" "$SSL_DEST_DIR/server.key"
        echo "证书文件已部署到 $SSL_DEST_DIR"
        reload_nginx
    else
        echo "错误: 压缩包内未找到 .crt 或 .key 文件"
    fi
    # 删除压缩包，防止重复处理
    rm -f "$zip_file"
}

# --- 5. 启动逻辑 ---

# 生成兜底证书
generate_dummy_cert

# 导出环境变量默认值
export HTTP_PORT=${HTTP_PORT:-80}
export HTTPS_PORT=${HTTPS_PORT:-5130}
export HOSTNAME=${HOSTNAME:-localhost}

# 生成配置文件
echo "生成 Nginx 配置..."
envsubst '$HTTP_PORT $HTTPS_PORT $HOSTNAME' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# 检查配置是否合法 (为了方便调试，如果配置错误会直接打印出来)
nginx -t -c /etc/nginx/nginx.conf
if [ $? -ne 0 ]; then
    echo "!!! 配置文件生成有误，打印文件内容如下 !!!"
    cat /etc/nginx/nginx.conf
    exit 1
fi

# 启动后台监控
(
    # 处理已有文件
    for f in "$SSL_WATCH_DIR"/*.zip; do [ -e "$f" ] && process_ssl_zip "$f"; done
    # 监听新文件
    inotifywait -m -e create -e moved_to --format "%w%f" "$SSL_WATCH_DIR" | while read file
    do
        if [[ "$file" == *.zip ]]; then
            sleep 1
            process_ssl_zip "$file"
        fi
    done
) &

# 启动 Nginx
echo "启动 Nginx (HTTP:$HTTP_PORT, HTTPS:$HTTPS_PORT)..."
exec nginx -g "daemon off;"
