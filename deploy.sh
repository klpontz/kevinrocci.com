#!/usr/bin/env bash
#
# Deploy kevinrocci.com to Bluehost over SSH/SFTP.
#
#   ./deploy.sh --dry-run    show what would change, transfer nothing
#   ./deploy.sh              upload
#
# Credentials live in .deploy.env, which is gitignored and never
# committed. Copy .deploy.env.example and fill it in.
#
# Two transfer paths. rsync is used when the host allows SSH commands —
# it only sends changed files and can preview with --dry-run. Bluehost
# shared plans sometimes permit SFTP but not a login shell, in which
# case the script falls back to an sftp batch that mirrors the tree.
#
set -euo pipefail

cd "$(dirname "$0")"

DRY_RUN=0
FORCE_SFTP=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --sftp)    FORCE_SFTP=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f .deploy.env ]]; then
  echo "error: .deploy.env not found." >&2
  echo "       cp .deploy.env.example .deploy.env  and fill it in." >&2
  exit 1
fi
# shellcheck disable=SC1091
source .deploy.env

for var in SFTP_HOST SFTP_USER REMOTE_DIR; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is not set in .deploy.env" >&2
    exit 1
  fi
done
SFTP_PORT="${SFTP_PORT:-22}"

# Everything the live site needs, and nothing else. The generator, the
# README and the git metadata stay local.
PAYLOAD=(index.html style.css nav.js favicon.svg img work)

for path in "${PAYLOAD[@]}"; do
  [[ -e "$path" ]] || { echo "error: missing $path" >&2; exit 1; }
done

SSH_OPTS=(-p "$SFTP_PORT")
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=(-i "$SSH_KEY")

echo "target: $SFTP_USER@$SFTP_HOST:$REMOTE_DIR (port $SFTP_PORT)"

# ---------------------------------------------------------------- rsync

if [[ $FORCE_SFTP -eq 0 ]] && ssh "${SSH_OPTS[@]}" -o BatchMode=yes \
      -o ConnectTimeout=10 "$SFTP_USER@$SFTP_HOST" true 2>/dev/null; then

  echo "transport: rsync over ssh"
  RSYNC_OPTS=(-avz --delete --omit-dir-times --no-perms
              --exclude '.DS_Store'
              -e "ssh ${SSH_OPTS[*]}")
  [[ $DRY_RUN -eq 1 ]] && RSYNC_OPTS+=(--dry-run) && echo "MODE: dry run"

  rsync "${RSYNC_OPTS[@]}" "${PAYLOAD[@]}" \
        "$SFTP_USER@$SFTP_HOST:$REMOTE_DIR/"

  echo "done."
  exit 0
fi

# ---------------------------------------------------------------- sftp

echo "transport: sftp batch (no ssh shell on this host)"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "MODE: dry run — sftp cannot preview, so this only lists the payload:"
  find "${PAYLOAD[@]}" -type f -not -name '.DS_Store' | sed 's/^/  /'
  exit 0
fi

BATCH="$(mktemp -t krdeploy)"
trap 'rm -f "$BATCH"' EXIT

{
  echo "cd $REMOTE_DIR"
  # -mkdir does not fail when the directory already exists.
  echo "-mkdir img"
  echo "-mkdir img/magpie"
  echo "-mkdir work"
  echo "-mkdir work/hiring-automation"
  for f in index.html style.css nav.js favicon.svg; do
    echo "put $f"
  done
  echo "put img/feather.svg img/feather.svg"
  for f in img/magpie/*.png; do
    echo "put $f $f"
  done
  echo "put work/hiring-automation/index.html work/hiring-automation/index.html"
  echo "bye"
} > "$BATCH"

sftp -P "$SFTP_PORT" ${SSH_KEY:+-i "$SSH_KEY"} -b "$BATCH" \
     "$SFTP_USER@$SFTP_HOST"

echo "done."
