#!/usr/bin/env bash
#
# Deploy kevinrocci.com to Bluehost over SSH/SFTP.
#
#   ./deploy.sh --dry-run    show what would change, transfer nothing
#   ./deploy.sh              upload
#   ./deploy.sh --claim      first deploy into a directory this script
#                            has not written to before
#
# This account hosts more than one site. The script therefore refuses to
# write to a remote directory it does not recognise: it drops a marker
# file, .deployed-by-kevinrocci-repo, on first use and checks for it on
# every run. rsync --delete mirrors the repo exactly, so a wrong
# REMOTE_DIR without this guard would erase whatever lives there.
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
FORCE_CLAIM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --sftp)    FORCE_SFTP=1 ;;
    --claim)   FORCE_CLAIM=1 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
PAYLOAD=(.htaccess index.html style.css nav.js favicon.svg img work)

for path in "${PAYLOAD[@]}"; do
  [[ -e "$path" ]] || { echo "error: missing $path" >&2; exit 1; }
done

SSH_OPTS=(-p "$SFTP_PORT")
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=(-i "$SSH_KEY")

echo "target: $SFTP_USER@$SFTP_HOST:$REMOTE_DIR (port $SFTP_PORT)"

# ---------------------------------------------------------------- rsync

# Detect a real shell by its OUTPUT, not its exit code. Bluehost's
# shared plans accept the SSH connection, print "Shell access is not
# enabled on your account!", and still exit 0 — so testing $? picks
# rsync on a host that cannot run it.
shell_probe=$(ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o ConnectTimeout=10 \
              "$SFTP_USER@$SFTP_HOST" 'echo __SHELL_OK__' 2>/dev/null || true)

if [[ $FORCE_SFTP -eq 0 && "$shell_probe" == *__SHELL_OK__* ]]; then

  echo "transport: rsync over ssh"

  # --- ownership guard -------------------------------------------------
  # Refuse to --delete inside a directory this script has not claimed.
  MARKER=".deployed-by-kevinrocci-repo"
  remote_state=$(ssh "${SSH_OPTS[@]}" "$SFTP_USER@$SFTP_HOST" \
    "if [ ! -d '$REMOTE_DIR' ]; then echo missing;
     elif [ -f '$REMOTE_DIR/$MARKER' ]; then echo claimed;
     elif [ -z \"\$(ls -A '$REMOTE_DIR' 2>/dev/null)\" ]; then echo empty;
     else echo occupied; fi" 2>/dev/null)

  case "$remote_state" in
    missing)
      echo "error: $REMOTE_DIR does not exist on the server." >&2
      echo "       Check REMOTE_DIR in .deploy.env." >&2
      exit 1 ;;
    occupied)
      if [[ $FORCE_CLAIM -eq 0 ]]; then
        echo "" >&2
        echo "STOP. $REMOTE_DIR already holds files, and none of them were" >&2
        echo "put there by this script. Another site may live here." >&2
        echo "" >&2
        echo "This deploy uses rsync --delete and would remove them." >&2
        echo "" >&2
        echo "Look first:" >&2
        echo "  ssh ${SSH_OPTS[*]} $SFTP_USER@$SFTP_HOST 'ls -la $REMOTE_DIR'" >&2
        echo "" >&2
        echo "If that really is the right empty-ish home for this site," >&2
        echo "re-run with --claim." >&2
        exit 1
      fi
      echo "WARNING: claiming an occupied directory (--claim given)." ;;
    empty|claimed) ;;
    *)
      echo "error: could not inspect $REMOTE_DIR on the server." >&2
      exit 1 ;;
  esac
  echo "remote: $remote_state"
  # ---------------------------------------------------------------------

  RSYNC_OPTS=(-avz --delete --omit-dir-times --no-perms
              --exclude "$MARKER"
              --exclude '.DS_Store'
              -e "ssh ${SSH_OPTS[*]}")
  [[ $DRY_RUN -eq 1 ]] && RSYNC_OPTS+=(--dry-run) && echo "MODE: dry run"

  rsync "${RSYNC_OPTS[@]}" "${PAYLOAD[@]}" \
        "$SFTP_USER@$SFTP_HOST:$REMOTE_DIR/"

  if [[ $DRY_RUN -eq 0 ]]; then
    ssh "${SSH_OPTS[@]}" "$SFTP_USER@$SFTP_HOST" \
        "touch '$REMOTE_DIR/$MARKER'"
  fi

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
  for f in .htaccess index.html style.css nav.js favicon.svg; do
    echo "put $f"
  done
  echo "put img/magpie.svg img/magpie.svg"
  for f in img/magpie/*.png; do
    echo "put $f $f"
  done
  echo "put work/hiring-automation/index.html work/hiring-automation/index.html"
  echo "bye"
} > "$BATCH"

sftp -P "$SFTP_PORT" ${SSH_KEY:+-i "$SSH_KEY"} -b "$BATCH" \
     "$SFTP_USER@$SFTP_HOST"

echo "done."
