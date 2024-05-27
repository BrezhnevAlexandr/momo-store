# Этап сборки
FROM golang:1.17 as builder
ARG VERSION=${VERSION}
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod tidy
COPY . .
WORKDIR /usr/src/app/cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -o /usr/src/app/myapp -ldflags "-X main.Version=${VERSION}"

# Этап релиза
FROM alpine:latest
ARG VERSION=${VERSION}
WORKDIR /app
COPY --from=builder /usr/src/app/myapp .
EXPOSE 8081
ENTRYPOINT ["./myapp"]
HEALTHCHECK --interval=60s --retries=5 --start-period=5s --timeout=10s CMD wget -q --spider http://localhost:8081/health || exit 1
