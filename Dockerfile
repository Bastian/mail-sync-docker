# Stage 1: Build goimapnotify
FROM golang:1.25-alpine AS builder

RUN go install gitlab.com/shackra/goimapnotify@2.5.4

# Stage 2: Final image
FROM alpine:3.19

RUN apk add --no-cache \
    isync \
    ca-certificates \
    bash \
    tini \
    openssl

COPY --from=builder /go/bin/goimapnotify /usr/local/bin/goimapnotify

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["goimapnotify", "-conf", "/tmp/goimapnotify.json"]
