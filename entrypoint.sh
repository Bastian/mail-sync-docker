#!/usr/bin/env bash
set -euo pipefail

# Default values
IMAP_PORT="${IMAP_PORT:-993}"
MAILDIR_PATH="${MAILDIR_PATH:-/mail}"

# Config files (ephemeral, regenerated on every start)
MBSYNC_CONFIG="/tmp/mbsyncrc"
NOTIFY_CONFIG="/tmp/goimapnotify.conf"

# Validate required environment variables
if [ -z "${IMAP_HOST:-}" ]; then
    echo "ERROR: IMAP_HOST is required"
    exit 1
fi

if [ -z "${IMAP_USER:-}" ]; then
    echo "ERROR: IMAP_USER is required"
    exit 1
fi

if [ -z "${IMAP_PASS:-}" ]; then
    echo "ERROR: IMAP_PASS is required"
    exit 1
fi

echo "Configuring mail sync for $IMAP_USER@$IMAP_HOST"

# Create Maildir structure
mkdir -p "$MAILDIR_PATH"

# Generate mbsyncrc
cat > "$MBSYNC_CONFIG" << EOF
IMAPAccount default
Host ${IMAP_HOST}
Port ${IMAP_PORT}
User ${IMAP_USER}
Pass ${IMAP_PASS}
SSLType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore default-remote
Account default

MaildirStore default-local
Path ${MAILDIR_PATH}/
Inbox ${MAILDIR_PATH}/INBOX
SubFolders Verbatim

Channel default
Far :default-remote:
Near :default-local:
Patterns *
Create Near
Expunge Both
SyncState *
EOF

chmod 600 "$MBSYNC_CONFIG"

# Generate goimapnotify config
cat > "$NOTIFY_CONFIG" << EOF
{
  "host": "${IMAP_HOST}",
  "port": ${IMAP_PORT},
  "tls": true,
  "tlsOptions": {
    "rejectUnauthorized": true
  },
  "username": "${IMAP_USER}",
  "password": "${IMAP_PASS}",
  "boxes": ["INBOX"],
  "onNewMail": "mbsync -c ${MBSYNC_CONFIG} -a",
  "onNewMailPost": "",
  "wait": 1
}
EOF

chmod 600 "$NOTIFY_CONFIG"

# Initial sync
echo "Running initial sync..."
mbsync -c "$MBSYNC_CONFIG" -a

echo "Initial sync complete. Starting IDLE watcher..."

exec "$@"
