# Этап сборки
FROM node:16-alpine as builder
WORKDIR /usr/src/app
COPY . .
RUN npm install
RUN npm run build

# Этап релиза
FROM nginx:stable-alpine
EXPOSE 80
COPY --from=builder /usr/src/app/dist/ /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf
ENV VUE_APP_API_URL=http://backend:8081
ENV NODE_ENV=production
CMD ["nginx", "-g", "daemon off;"]