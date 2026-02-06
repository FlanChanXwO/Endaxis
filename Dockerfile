# 第一阶段：构建环境
FROM node:18-alpine as build-stage

# 设置工作目录
WORKDIR /app

# 复制 package.json 并安装依赖
COPY package*.json ./
# 如果你有 lock 文件最好也复制，没有则忽略
# COPY package-lock.json ./ 
RUN npm install

# 复制源代码
COPY . .

# 执行 Vite 构建 (通常生成在 dist 目录)
RUN npm run build

# 第二阶段：生产环境 (Nginx)
FROM nginx:alpine as production-stage

# 删除默认配置
RUN rm /etc/nginx/conf.d/default.conf

# 复制我们自定义的 nginx 配置 (监听 5130)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 从第一阶段复制构建好的静态文件到 Nginx 目录
COPY --from=build-stage /app/dist /usr/share/nginx/html

# 暴露 5130 端口
EXPOSE 5130

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
