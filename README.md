# Mail Sync Docker

A Docker image for syncing emails from an IMAP server to local Maildir using
[mbsync](https://isync.sourceforge.io/) with IMAP IDLE support via
[goimapnotify](https://gitlab.com/shackra/goimapnotify).

> [!WARNING]
> For use on my private home server. Use at your own risk. There are no plans to
> add features beyond what I need for myself.

## Quick Start

### 1. Build the Image

```bash
docker build -t mail-sync .
```

### 2. Run

```bash
mkdir -p ./mail
docker run -d --name mail-sync \
    -e IMAP_HOST=imap.example.com \
    -e IMAP_USER=your-email@example.com \
    -e IMAP_PASS=your-password \
    -v ./mail:/mail \
    --user "$(id -u):$(id -g)" \
    --restart unless-stopped \
    mail-sync
```

### 3. View Logs

```bash
docker logs -f mail-sync
```

## Environment Variables

| Variable          | Required | Default | Description                          |
| ----------------- | -------- | ------- | ------------------------------------ |
| `IMAP_HOST`       | Yes      | -       | IMAP server hostname                 |
| `IMAP_USER`       | Yes      | -       | IMAP username                        |
| `IMAP_PASS`       | Yes      | -       | IMAP password                        |
| `IMAP_PORT`       | No       | 993     | IMAP port                            |
| `IMAP_TLS`        | No       | IMAPS   | TLS mode: IMAPS, STARTTLS, or None   |
| `TLS_SKIP_VERIFY` | No       | false   | Accept self-signed certificates      |
| `MAILDIR_PATH`    | No       | /mail   | Path inside container                |

## Volumes

| Path    | Description                       |
| ------- | --------------------------------- |
| `/mail` | Maildir storage for synced emails |

**Important**: Persist this volume to retain your emails across container restarts.

## How It Works

1. On startup, generates mbsync and goimapnotify configs from environment variables
2. Runs an initial full sync with `mbsync -a`
3. Starts goimapnotify which connects via IMAP IDLE
4. When new mail arrives, goimapnotify triggers mbsync to sync immediately
