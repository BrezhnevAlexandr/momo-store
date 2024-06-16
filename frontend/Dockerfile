# Этап сборки
FROM huecker.io/library/node:16 as builder
WORKDIR /usr/src/app
COPY . .
RUN npm install
RUN npm run build

# Этап релиза
FROM huecker.io/library/nginx:stable-alpine
EXPOSE 80
COPY --from=builder /usr/src/app/dist/ /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]