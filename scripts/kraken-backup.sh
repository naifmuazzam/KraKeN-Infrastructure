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
ENCRYPTED_ARCHIVE="${ARCHIVE}.age"
MANIFEST="${BACKUP_DIR}/kraken-backup-${TIMESTAMP}.manifest"
CHECKSUM="${BACKUP_DIR}/kraken-backup-${TIMESTAMP}.sha256"

R2_ENV="/opt/kraken/secrets/r2.env"
R2_REGION="us-east-1"

echo "== KraKeN Backup =="
echo "Timestamp : ${TIMESTAMP}"
echo "Backup dir: ${BACKUP_DIR}"
echo

mkdir -p "${BACKUP_DIR}"

echo "[1/8] Validating backup source..."

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
echo "[2/8] Creating manifest..."

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
echo "[3/8] Creating compressed archive..."

tar \
    --exclude='kraken/backups' \
    --exclude='kraken/compose/.env' \
    --exclude='kraken/secrets' \
    --exclude='kraken/data/prometheus/lock' \
    --exclude='kraken/data/prometheus/queries.active' \
    -C /opt \
    -cf - kraken \
    | zstd -T2 -6 -o "${ARCHIVE}"

echo "Archive created: ${ARCHIVE}"

echo
echo "[4/8] Encrypting archive with age..."

RECIPIENT="$(age-keygen -y /opt/kraken/secrets/backup.agekey)"
age -r "${RECIPIENT}" -o "${ENCRYPTED_ARCHIVE}" "${ARCHIVE}"
rm -f "${ARCHIVE}"

echo "Encrypted archive created: ${ENCRYPTED_ARCHIVE}"

echo
echo "[5/8] Generating SHA-256 checksum..."

sha256sum "${ENCRYPTED_ARCHIVE}" > "${CHECKSUM}"

echo "Checksum created: ${CHECKSUM}"

echo
echo "[6/8] Verifying backup files..."

test -s "${ENCRYPTED_ARCHIVE}"
test -s "${MANIFEST}"
test -s "${CHECKSUM}"

sha256sum -c "${CHECKSUM}"

echo
echo "[7/8] Uploading encrypted backup to Cloudflare R2..."

if [[ ! -f "${R2_ENV}" ]]; then
    echo "ERROR: R2 environment file not found: ${R2_ENV}" >&2
    exit 1
fi

source "${R2_ENV}"

for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET R2_ENDPOINT; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: Missing R2 variable: ${var}" >&2
        exit 1
    fi
done

R2_YEAR="${TIMESTAMP:0:4}"
R2_MONTH="${TIMESTAMP:5:2}"
R2_KEY="${R2_YEAR}/${R2_MONTH}/kraken-backup-${TIMESTAMP}.tar.zst.age"

AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" AWS_DEFAULT_REGION="${R2_REGION}" \
aws s3 cp "${ENCRYPTED_ARCHIVE}" "s3://${R2_BUCKET}/${R2_KEY}" \
    --endpoint-url "${R2_ENDPOINT}"

echo "R2 upload: OK"

echo
echo "[8/8] Verifying R2 object..."

AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" AWS_DEFAULT_REGION="${R2_REGION}" \
aws s3api head-object \
    --bucket "${R2_BUCKET}" \
    --key "${R2_KEY}" \
    --endpoint-url "${R2_ENDPOINT}" >/dev/null

echo "R2 verification: OK"

echo
echo "Backup completed successfully."
echo
echo "Archive : ${ENCRYPTED_ARCHIVE}"
echo "Manifest: ${MANIFEST}"
echo "SHA256  : ${CHECKSUM}"
