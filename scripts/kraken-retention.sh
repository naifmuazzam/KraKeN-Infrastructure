#!/bin/bash

set -euo pipefail

BACKUP_DIR="/opt/kraken/backups"
R2_ENV="/opt/kraken/secrets/r2.env"
R2_REGION="us-east-1"

DAILY_KEEP=7
WEEKLY_KEEP=4
MONTHLY_KEEP=3

DRY_RUN=false

echo "== KraKeN Backup Retention =="
echo "Local backup dir : ${BACKUP_DIR}"
echo "Daily keep       : ${DAILY_KEEP}"
echo "Weekly keep      : ${WEEKLY_KEEP}"
echo "Monthly keep     : ${MONTHLY_KEEP}"
if [[ "${DRY_RUN}" == "true" ]]; then
    MODE="DRY-RUN"
else
    MODE="LIVE"
fi

echo "Mode             : ${MODE}"
echo

###############################################################################
# Local backup discovery
###############################################################################

mapfile -t LOCAL_BACKUPS < <(
    find "${BACKUP_DIR}" \
        -maxdepth 1 \
        -type f \
        -name "kraken-backup-*.tar.zst.age" \
        -printf "%f\n" |
    sort -r
)

echo "Local encrypted backups: ${#LOCAL_BACKUPS[@]}"

###############################################################################
# R2 backup discovery
###############################################################################

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

mapfile -t R2_BACKUPS < <(
    AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
    AWS_DEFAULT_REGION="${R2_REGION}" \
    aws s3 ls "s3://${R2_BUCKET}" \
        --recursive \
        --endpoint-url "${R2_ENDPOINT}" |
    awk '{print $4}' |
    grep -E '/kraken-backup-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}\.tar\.zst\.age$' |
    sed 's#^.*/##' |
    sort -r
)

echo "R2 encrypted backups   : ${#R2_BACKUPS[@]}"

###############################################################################
# Retention calculation function
###############################################################################

calculate_retention() {
    local -n backups_ref="$1"
    local -n daily_ref="$2"
    local -n weekly_ref="$3"
    local -n monthly_ref="$4"
    local -n keep_ref="$5"

    local backup
    local timestamp
    local date_part
    local day
    local week
    local month

    for backup in "${backups_ref[@]}"; do
        timestamp="${backup#kraken-backup-}"
        timestamp="${timestamp%.tar.zst.age}"

        if [[ ! "${timestamp}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]]; then
            echo "WARNING: Skipping unexpected filename: ${backup}" >&2
            continue
        fi

        date_part="${timestamp:0:10}"
        day="${date_part}"
        week="$(date -u -d "${date_part}" '+%G-W%V')"
        month="${timestamp:0:7}"

        if [[ -z "${daily_ref[$day]:-}" ]]; then
            daily_ref["${day}"]="${backup}"
        fi

        if [[ -z "${weekly_ref[$week]:-}" ]]; then
            weekly_ref["${week}"]="${backup}"
        fi

        if [[ -z "${monthly_ref[$month]:-}" ]]; then
            monthly_ref["${month}"]="${backup}"
        fi
    done

    local -a selected_days=()
    local -a selected_weeks=()
    local -a selected_months=()

    mapfile -t selected_days < <(
        printf '%s\n' "${!daily_ref[@]}" |
        sort -r |
        head -n "${DAILY_KEEP}"
    )

    for day in "${selected_days[@]}"; do
        keep_ref["${daily_ref[$day]}"]=1
    done

    mapfile -t selected_weeks < <(
        printf '%s\n' "${!weekly_ref[@]}" |
        sort -r |
        head -n "${WEEKLY_KEEP}"
    )

    for week in "${selected_weeks[@]}"; do
        keep_ref["${weekly_ref[$week]}"]=1
    done

    mapfile -t selected_months < <(
        printf '%s\n' "${!monthly_ref[@]}" |
        sort -r |
        head -n "${MONTHLY_KEEP}"
    )

    for month in "${selected_months[@]}"; do
        keep_ref["${monthly_ref[$month]}"]=1
    done
}

###############################################################################
declare -A LOCAL_DAILY LOCAL_WEEKLY LOCAL_MONTHLY LOCAL_KEEP
declare -A R2_DAILY R2_WEEKLY R2_MONTHLY R2_KEEP

declare -A LOCAL_DAILY LOCAL_WEEKLY LOCAL_MONTHLY LOCAL_KEEP
declare -A R2_DAILY R2_WEEKLY R2_MONTHLY R2_KEEP

# Calculate local and R2 retention sets
###############################################################################

calculate_retention LOCAL_BACKUPS LOCAL_DAILY LOCAL_WEEKLY LOCAL_MONTHLY LOCAL_KEEP
calculate_retention R2_BACKUPS R2_DAILY R2_WEEKLY R2_MONTHLY R2_KEEP

###############################################################################
# Local retention report
###############################################################################

echo
echo "== LOCAL RETENTION =="

echo
echo "Daily representatives:"
for day in $(printf '%s\n' "${!LOCAL_DAILY[@]}" | sort -r); do
    echo "  ${day} -> ${LOCAL_DAILY[$day]}"
done

echo
echo "Weekly representatives:"
for week in $(printf '%s\n' "${!LOCAL_WEEKLY[@]}" | sort -r); do
    echo "  ${week} -> ${LOCAL_WEEKLY[$week]}"
done

echo
echo "Monthly representatives:"
for month in $(printf '%s\n' "${!LOCAL_MONTHLY[@]}" | sort -r); do
    echo "  ${month} -> ${LOCAL_MONTHLY[$month]}"
done

echo
echo "Local keep set:"
for backup in "${LOCAL_BACKUPS[@]}"; do
    if [[ -n "${LOCAL_KEEP[$backup]:-}" ]]; then
        echo "  KEEP              ${backup}"
    fi
done

echo
echo "Local deletion candidates:"
for backup in "${LOCAL_BACKUPS[@]}"; do
    if [[ -z "${LOCAL_KEEP[$backup]:-}" ]]; then
        echo "  DELETE-CANDIDATE  ${backup}"
    fi
done

###############################################################################
# R2 retention report
###############################################################################

echo
echo "== R2 RETENTION =="

echo
echo "Daily representatives:"
for day in $(printf '%s\n' "${!R2_DAILY[@]}" | sort -r); do
    echo "  ${day} -> ${R2_DAILY[$day]}"
done

echo
echo "Weekly representatives:"
for week in $(printf '%s\n' "${!R2_WEEKLY[@]}" | sort -r); do
    echo "  ${week} -> ${R2_WEEKLY[$week]}"
done

echo
echo "Monthly representatives:"
for month in $(printf '%s\n' "${!R2_MONTHLY[@]}" | sort -r); do
    echo "  ${month} -> ${R2_MONTHLY[$month]}"
done

echo
echo "R2 keep set:"
for backup in "${R2_BACKUPS[@]}"; do
    if [[ -n "${R2_KEEP[$backup]:-}" ]]; then
        echo "  KEEP              ${backup}"
    fi
done

echo
echo "R2 deletion candidates:"
for backup in "${R2_BACKUPS[@]}"; do
    if [[ -z "${R2_KEEP[$backup]:-}" ]]; then
        echo "  DELETE-CANDIDATE  ${backup}"
    fi
done

###############################################################################
# Deletion
###############################################################################

echo
echo "== DELETION =="

# Local deletion
for backup in "${LOCAL_BACKUPS[@]}"; do
    if [[ -z "${LOCAL_KEEP[$backup]:-}" ]]; then
        base="${backup%.tar.zst.age}"

        if [[ "${DRY_RUN}" == "true" ]]; then
            echo "WOULD DELETE LOCAL: ${backup}"
            echo "WOULD DELETE LOCAL: ${base}.manifest"
            echo "WOULD DELETE LOCAL: ${base}.sha256"
        else
            rm -f "${BACKUP_DIR}/${backup}"
            rm -f "${BACKUP_DIR}/${base}.manifest"
            rm -f "${BACKUP_DIR}/${base}.sha256"
            echo "DELETED LOCAL: ${backup}"
        fi
    fi
done

# R2 deletion
for backup in "${R2_BACKUPS[@]}"; do
    if [[ -z "${R2_KEEP[$backup]:-}" ]]; then
        timestamp="${backup#kraken-backup-}"
        timestamp="${timestamp%.tar.zst.age}"
        year="${timestamp:0:4}"
        month="${timestamp:5:2}"
        r2_key="${year}/${month}/${backup}"

        if [[ "${DRY_RUN}" == "true" ]]; then
            echo "WOULD DELETE R2:    ${r2_key}"
        else
            AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
            AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
            AWS_DEFAULT_REGION="${R2_REGION}" \
            aws s3api head-object \
                --bucket "${R2_BUCKET}" \
                --key "${r2_key}" \
                --endpoint-url "${R2_ENDPOINT}" >/dev/null

            AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
            AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
            AWS_DEFAULT_REGION="${R2_REGION}" \
            aws s3 rm "s3://${R2_BUCKET}/${r2_key}" \
                --endpoint-url "${R2_ENDPOINT}"

            echo "DELETED R2:        ${r2_key}"
        fi
    fi
done

echo
echo "Retention evaluation complete."

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "DRY-RUN: No files or R2 objects were deleted."
else
    echo "Retention deletion complete."
fi
