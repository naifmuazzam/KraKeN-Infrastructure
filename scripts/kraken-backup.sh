#!/bin/bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    echo "Use: sudo ./scripts/kraken-backup.sh" >&2
    exit 1
fi

BACKUP_ROOT="/opt/kraken"
BACKUP_DIR="${BACKUP_ROOT}/backups"
TIMESTAMP="$(date -u '+%Y-%m-%d_%H%M%S')"

ARCHIVE="${BACKUP_DIR}/kraken-backup-${TIMESTAMP}.tar.zst"
MANIFEST="${BACKUP_DIR}/kraken-backup-${TIMESTAMP}.manifest"
CHECKSUM="${BACKUP_DIR}/kraken-backup-${TIMESTAMP}.sha256"

echo "== KraKeN Backup =="
echo "Timestamp : ${TIMESTAMP}"
echo "Backup dir: ${BACKUP_DIR}"
echo

mkdir -p "${BACKUP_DIR}"

echo "[1/5] Validating backup source..."

for path in \
    "${BACKUP_ROOT}/compose" \
    "${BACKUP_ROOT}/config" \
    "${BACKUP_ROOT}/scripts" \
    "${BACKUP_ROOT}/systemd" \
    "${BACKUP_ROOT}/data"
do
    if [[ ! -d "${path}" ]]; then
        echo "ERROR: Missing backup source: ${path}" >&2
        exit 1
    fi
done

echo "Source validation: OK"

echo
echo "[2/5] Creating manifest..."

cat > "${MANIFEST}" <<MANIFEST
KraKeN Infrastructure Backup
============================

Timestamp (UTC): ${TIMESTAMP}

Backup scope:
- /opt/kraken/compose
- /opt/kraken/config
- /opt/kraken/scripts
- /opt/kraken/systemd
- /opt/kraken/data

Excluded:
- /opt/kraken/backups
- /opt/kraken/compose/.env
- /opt/kraken/secrets
- /opt/kraken/data/prometheus/lock
- /opt/kraken/data/prometheus/queries.active

Secrets:
Secrets are handled separately and are not included in this archive.
MANIFEST

echo "Manifest created: ${MANIFEST}"

echo
echo "[3/5] Creating compressed archive..."

tar \
    --exclude='./backups' \
    --exclude='./compose/.env' \
    --exclude='./secrets' \
    --exclude='./data/prometheus/lock' \
    --exclude='./data/prometheus/queries.active' \
    -C /opt \
    -cf - kraken \
    | zstd -T0 -19 -o "${ARCHIVE}"

echo "Archive created: ${ARCHIVE}"

echo
echo "[4/5] Generating SHA-256 checksum..."

sha256sum "${ARCHIVE}" > "${CHECKSUM}"

echo "Checksum created: ${CHECKSUM}"

echo
echo "[5/5] Verifying backup files..."

test -s "${ARCHIVE}"
test -s "${MANIFEST}"
test -s "${CHECKSUM}"

sha256sum -c "${CHECKSUM}"

echo
echo "Backup completed successfully."
echo
echo "Archive : ${ARCHIVE}"
echo "Manifest: ${MANIFEST}"
echo "SHA256  : ${CHECKSUM}"
