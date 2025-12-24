#!/usr/bin/env bash
set -euo pipefail

# Default values
IMAP_PORT="${IMAP_PORT:-993}"
IMAP_TLS="${IMAP_TLS:-IMAPS}"
TLS_SKIP_VERIFY="${TLS_SKIP_VERIFY:-false}"
MAILDIR_PATH="${MAILDIR_PATH:-/mail}"

# Config files (ephemeral, regenerated on every start)
MBSYNC_CONFIG="/tmp/mbsyncrc"
NOTIFY_CONFIG="/tmp/goimapnotify.json"

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

# Handle certificate verification
CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
if [ "$TLS_SKIP_VERIFY" = "true" ] && [ "$IMAP_TLS" != "None" ]; then
    echo "Fetching server certificate (TLS_SKIP_VERIFY=true)..."
    CERT_FILE="/tmp/server-cert.pem"
    echo | openssl s_client -connect "${IMAP_HOST}:${IMAP_PORT}" -starttls imap 2>/dev/null | \
        openssl x509 > "$CERT_FILE" 2>/dev/null || \
    echo | openssl s_client -connect "${IMAP_HOST}:${IMAP_PORT}" 2>/dev/null | \
        openssl x509 > "$CERT_FILE" 2>/dev/null || true
fi

# Generate mbsyncrc
cat > "$MBSYNC_CONFIG" << EOF
IMAPAccount default
Host ${IMAP_HOST}
Port ${IMAP_PORT}
User ${IMAP_USER}
Pass ${IMAP_PASS}
SSLType ${IMAP_TLS}
CertificateFile ${CERT_FILE}

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

# Determine TLS settings for goimapnotify
if [ "$IMAP_TLS" = "IMAPS" ]; then
    NOTIFY_TLS="true"
    NOTIFY_STARTTLS="false"
elif [ "$IMAP_TLS" = "STARTTLS" ]; then
    NOTIFY_TLS="false"
    NOTIFY_STARTTLS="true"
else
    NOTIFY_TLS="false"
    NOTIFY_STARTTLS="false"
fi

if [ "$TLS_SKIP_VERIFY" = "true" ]; then
    NOTIFY_REJECT_UNAUTHORIZED="false"
else
    NOTIFY_REJECT_UNAUTHORIZED="true"
fi

# Generate goimapnotify config
cat > "$NOTIFY_CONFIG" << EOF
{
  "configurations": [
    {
      "host": "${IMAP_HOST}",
      "port": ${IMAP_PORT},
      "tls": ${NOTIFY_TLS},
      "tlsOptions": {
        "starttls": ${NOTIFY_STARTTLS},
        "rejectUnauthorized": ${NOTIFY_REJECT_UNAUTHORIZED}
      },
      "username": "${IMAP_USER}",
      "password": "${IMAP_PASS}",
      "onNewMail": "mbsync -c ${MBSYNC_CONFIG} -a",
      "onNewMailPost": "SKIP",
      "wait": 1,
      "boxes": [
        {
          "mailbox": "INBOX"
        }
      ]
    }
  ]
}
EOF

chmod 600 "$NOTIFY_CONFIG"

# Initial sync
echo "Running initial sync..."
mbsync -c "$MBSYNC_CONFIG" -a

echo "Initial sync complete. Starting IDLE watcher..."

exec "$@"
