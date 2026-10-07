#!/usr/bin/env bash
# Build an OSINT toolkit on a Linux host:
#   sherlock (this repo), blackbird, maigret, spiderfoot, theHarvester, shodan
#
# Each tool gets its own virtualenv (they need different Python versions and
# conflicting pins), and a wrapper script lands in $OSINT_HOME/bin.
#
# Usage:  ./install.sh [--with-browser]
#   OSINT_HOME   where everything lives (default: ~/osint)
#   --with-browser   also install Playwright's Chromium for theHarvester
#                    (needs sudo for system libraries)
#
# Upstream commits are pinned to what was validated on 2026-10-07.
# To move a tool forward, change its SHA below and re-run.
set -euo pipefail

OSINT_HOME="${OSINT_HOME:-$HOME/osint}"
SRC="$OSINT_HOME/src"
VENVS="$OSINT_HOME/venvs"
BIN="$OSINT_HOME/bin"
DATA="$OSINT_HOME/data"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHERLOCK_SRC="$(cd "$HERE/.." && pwd)"
WITH_BROWSER=0
[ "${1:-}" = "--with-browser" ] && WITH_BROWSER=1

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- prereqs
for cmd in git curl; do
  command -v "$cmd" >/dev/null || { echo "missing: $cmd (apt install $cmd)"; exit 1; }
done
if ! command -v uv >/dev/null; then
  log "installing uv (Python package/version manager)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
command -v uv >/dev/null || { echo "uv not on PATH after install"; exit 1; }

mkdir -p "$SRC" "$VENVS" "$BIN" "$DATA/spiderfoot/log" "$DATA/spiderfoot/cache"

log "installing Python interpreters"
uv python install 3.11 3.12 3.14

# fetch <name> <git url> <commit>
fetch() {
  local name=$1 url=$2 sha=$3 dir="$SRC/$1"
  log "fetching $name @ ${sha:0:12}"
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$sha"
  git -C "$dir" checkout -q --detach FETCH_HEAD
}

fetch blackbird     https://github.com/antoniaci/blackbird     b45505080ef51bb3ef52dc29879ee6bef31e5b94
fetch maigret       https://github.com/soxoj/maigret            5b590c4ff3da17576f6b0b3d7bf8abac3a50c41a
fetch spiderfoot    https://github.com/smicallef/spiderfoot     0f815a203afebf05c98b605dba5cf0475a0ee5fd
fetch theHarvester  https://github.com/laramies/theHarvester    49a38f8d33c32336bbf6a111ea723ea223116265
fetch shodan-python https://github.com/achillean/shodan-python  87a0688d1e5b7e4bb13ae4f5fd7cb937a671cba8

# venv <name> <python version>
venv() { uv venv -q --allow-existing -p "$2" "$VENVS/$1"; echo "$VENVS/$1/bin/python"; }

log "sherlock"
py=$(venv sherlock 3.12)
uv pip install -q -p "$py" "$SHERLOCK_SRC"

log "blackbird"
py=$(venv blackbird 3.12)
uv pip install -q -p "$py" -r "$SRC/blackbird/requirements.txt"

log "maigret"
py=$(venv maigret 3.12)
uv pip install -q -p "$py" "$SRC/maigret"

log "spiderfoot"
# upstream pins (lxml<5, cryptography<4) only have wheels up to Python 3.11
py=$(venv spiderfoot 3.11)
uv pip install -q -p "$py" -r "$SRC/spiderfoot/requirements.txt"

log "theHarvester"
( cd "$SRC/theHarvester" && UV_PROJECT_ENVIRONMENT="$VENVS/theharvester" uv sync -q --locked --no-dev )
if [ "$WITH_BROWSER" = 1 ]; then
  log "theHarvester: Playwright Chromium"
  "$VENVS/theharvester/bin/playwright" install --with-deps chromium
fi

log "shodan"
py=$(venv shodan 3.12)
# shodan's CLI still imports pkg_resources, which setuptools>=81 dropped
uv pip install -q -p "$py" "$SRC/shodan-python" 'setuptools<81'

# ---------------------------------------------------------------- wrappers
log "writing wrappers to $BIN"
wrap() { # wrap <name> <body>
  printf '#!/usr/bin/env bash\nset -euo pipefail\nOSINT_HOME=%q\n%s\n' "$OSINT_HOME" "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}
wrap sherlock     'exec "$OSINT_HOME/venvs/sherlock/bin/sherlock" "$@"'
wrap blackbird    'cd "$OSINT_HOME/src/blackbird" && exec "$OSINT_HOME/venvs/blackbird/bin/python" blackbird.py "$@"'
wrap maigret      'exec "$OSINT_HOME/venvs/maigret/bin/maigret" "$@"'
wrap spiderfoot   'cd "$OSINT_HOME/src/spiderfoot"
export SPIDERFOOT_DATA="$OSINT_HOME/data/spiderfoot"
export SPIDERFOOT_LOGS="$SPIDERFOOT_DATA/log"
export SPIDERFOOT_CACHE="$SPIDERFOOT_DATA/cache"
[ $# -eq 0 ] && set -- -l 127.0.0.1:5001
exec "$OSINT_HOME/venvs/spiderfoot/bin/python" sf.py "$@"'
wrap sfcli        'cd "$OSINT_HOME/src/spiderfoot" && exec "$OSINT_HOME/venvs/spiderfoot/bin/python" sfcli.py "$@"'
wrap theHarvester 'exec "$OSINT_HOME/venvs/theharvester/bin/theHarvester" "$@"'
wrap harvestview  'exec "$OSINT_HOME/venvs/theharvester/bin/harvestview" "$@"'
wrap harvest-report 'exec "$OSINT_HOME/venvs/theharvester/bin/harvest-report" "$@"'
wrap shodan       'export PYTHONWARNINGS="ignore::UserWarning"
exec "$OSINT_HOME/venvs/shodan/bin/shodan" "$@"'

# ---------------------------------------------------------------- smoke test
log "smoke test"
"$BIN/sherlock" --version
"$BIN/blackbird" --help >/dev/null && echo "blackbird ok"
"$BIN/maigret" --version 2>&1 | tail -1
"$BIN/spiderfoot" --help >/dev/null && echo "spiderfoot ok"
"$BIN/theHarvester" -h >/dev/null 2>&1 && echo "theHarvester ok"
"$BIN/shodan" version 2>/dev/null

log "done"
cat <<MSG
Add the wrappers to your PATH:
  echo 'export PATH="$BIN:\$PATH"' >> ~/.bashrc && source ~/.bashrc
Then try:
  sherlock someuser            blackbird -u someuser
  maigret someuser             shodan init <API_KEY> && shodan host 8.8.8.8
  theHarvester -d example.com -b crtsh
  spiderfoot                   # web UI on http://127.0.0.1:5001
MSG
