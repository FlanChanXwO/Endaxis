#!/bin/bash

# --- 1. 配置路径 ---
SSL_WATCH_DIR="/app/ssl"           # 外部挂载的压缩包目录
SSL_DEST_DIR="/etc/nginx/certs"    # Nginx 实际读取证书的目录
TEMP_DIR="/tmp/ssl_extract"        # 临时解压区

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

# --- 3. 核心函数: 处理 ZIP ---
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
        echo "证书更新成功，正在重载 Nginx..."
        nginx -s reload
    else
        echo "错误: 压缩包内未找到 .crt 或 .key 文件"
    fi
    rm -f "$zip_file"
}

# --- 4. 启动逻辑 ---

# 生成兜底证书
generate_dummy_cert

# 导出环境变量默认值
export HTTP_PORT=${HTTP_PORT:-80}
export HTTPS_PORT=${HTTPS_PORT:-5130} # 默认 HTTPS 端口设为 5130
export HOSTNAME=${HOSTNAME:-localhost}

# 使用 envsubst 替换 nginx 配置模板
# 注意：这里我们保留 $uri 变量不被替换，只替换我们指定的变量
echo "生成 Nginx 配置..."
envsubst '$HTTP_PORT $HTTPS_PORT $HOSTNAME' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

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
