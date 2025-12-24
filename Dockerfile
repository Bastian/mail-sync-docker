# Stage 1: Build goimapnotify
FROM golang:1.21-alpine AS builder

RUN go install gitlab.com/shackra/goimapnotify@latest

# Stage 2: Final image
FROM alpine:3.19

RUN apk add --no-cache \
    isync \
    ca-certificates \
    bash \
    tini

COPY --from=builder /go/bin/goimapnotify /usr/local/bin/goimapnotify

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN adduser -D -h /home/mailsync mailsync && \
    mkdir -p /mail && \
    chown -R mailsync:mailsync /mail
USER mailsync
WORKDIR /home/mailsync
ENV HOME=/home/mailsync

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["goimapnotify", "-conf", "/home/mailsync/.goimapnotify.conf"]
