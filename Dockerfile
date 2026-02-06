# 第一阶段：构建 (使用 Node 20 解决 hash 问题)
FROM node:20-alpine AS build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# 第二阶段：生产环境 (集成智能脚本)
FROM nginx:alpine AS production-stage

# 1. 安装必要的工具 (Shell, Unzip, Inotify, OpenSSL)
RUN apk add --no-cache bash unzip inotify-tools openssl

# 2. 清理默认配置
RUN rm /etc/nginx/conf.d/default.conf

# 3. 复制我们的模板配置
# 注意：这里我们放到 templates 目录，虽然我们的脚本会手动处理它
COPY nginx.conf.template /etc/nginx/templates/nginx.conf.template

# 4. 复制静态资源 (Vue 打包产物)
COPY --from=build-stage /app/dist /usr/share/nginx/html

# 5. 复制并设置启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 6. 设置工作目录和 SSL 挂载点
WORKDIR /app
VOLUME ["/app/ssl"]

# 7. 暴露端口 (默认 HTTP 80, HTTPS 5130)
EXPOSE 80 5130

# 8. 使用自定义脚本启动
CMD ["/app/entrypoint.sh"]
