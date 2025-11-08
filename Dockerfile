FROM alpine:latest

RUN apk add --no-cache \
    bash \
    inotify-tools \
    rclone \
    ca-certificates

WORKDIR /app

COPY rclone-watch.sh /app/rclone-watch.sh
RUN chmod +x /app/rclone-watch.sh

CMD ["/app/rclone-watch.sh"]
