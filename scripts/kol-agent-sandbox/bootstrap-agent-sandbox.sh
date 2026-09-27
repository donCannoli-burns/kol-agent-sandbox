#!/usr/bin/env bash
set -euo pipefail

ROOT="./kolmafia"
LIVE="${HOME}/.kolmafia"
BRANCH=""
MOCK_REF="${KOLMAFIA_MOCK_REF:-5c53bf4a5ee64d84710e7788409862bd8d2a1661}"
DO_INSTALL=1

usage() {
  cat <<'EOF'
Usage:
  bootstrap-agent-sandbox.sh [options]

Options:
  --root PATH        sandbox top level (default: ./kolmafia)
  --live PATH        live KoLmafia root (default: ~/.kolmafia)
  --branch NAME      branch/sandbox name (default: current git branch or main)
  --mock-ref REF     kolmafia-mock commit/branch
  --no-install       clone/update source but skip Yarn install/test
  -h, --help         show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --live) LIVE="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --mock-ref) MOCK_REF="$2"; shift 2 ;;
    --no-install) DO_INSTALL=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  [[ -n "$BRANCH" ]] || BRANCH="main"
fi

SAFE_BRANCH="${BRANCH//../_}"
SAFE_BRANCH="${SAFE_BRANCH//\//__}"
SAFE_BRANCH="${SAFE_BRANCH// /-}"

BRANCH_ROOT="$ROOT/sandboxes/$SAFE_BRANCH"
MIRROR_DIR="$BRANCH_ROOT/mirror"
WORK_DIR="$BRANCH_ROOT/work"
MOCK_DIR="$BRANCH_ROOT/mock/kolmafia-mock"

mkdir -p "$BRANCH_ROOT/fixtures" "$MIRROR_DIR" "$WORK_DIR" "$BRANCH_ROOT/mock" "$BRANCH_ROOT/logs"

notice() {
  cat <<EOF
<aside data-kolmafia-agent-sandbox-notice="1" style="border:2px solid #ffc857;background:#171c1d;color:#e9f0fa;padding:14px 16px;margin:0 0 18px;border-radius:12px;font-family:system-ui,sans-serif">
  <strong style="color:#ffc857">AGENT SANDBOX NOTICE</strong>
  <div><b>Sandbox:</b> <code>$BRANCH_ROOT</code></div>
  <div><b>Live:</b> <code>$LIVE</code></div>
  <div style="color:#95a4b8">Work in the sandbox copy. Never fall through to live KoLmafia because a mock/test path failed.</div>
</aside>
EOF
}

decorate_readme() {
  local p="$1"
  [[ -f "$p" ]] || return 1
  if grep -q 'data-kolmafia-agent-sandbox-notice' "$p"; then
    return 0
  fi
  cp -a "$p" "$p.pre-agent-sandbox.bak"
  local tmp
  tmp="$(mktemp)"
  notice > "$tmp"
  cat "$p" >> "$tmp"
  mv "$tmp" "$p"
}

# If a live HTML README exists, copy it into the sandbox before decorating the copy.
if [[ ! -f "$BRANCH_ROOT/README.html5" && ! -f "$BRANCH_ROOT/README.html" ]]; then
  if [[ -f "$LIVE/README.html5" ]]; then
    cp -a "$LIVE/README.html5" "$BRANCH_ROOT/README.html5"
  elif [[ -f "$LIVE/README.html" ]]; then
    cp -a "$LIVE/README.html" "$BRANCH_ROOT/README.html"
  fi
fi

if ! decorate_readme "$BRANCH_ROOT/README.html5"; then
  if ! decorate_readme "$BRANCH_ROOT/README.html"; then
    {
      echo '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KoL Agent Sandbox</title></head>'
      echo '<body style="background:#090d12;color:#e9f0fa;font:15px/1.5 system-ui,sans-serif;max-width:1050px;margin:auto;padding:24px">'
      notice
      echo "<h1>Branch sandbox · $SAFE_BRANCH</h1>"
      echo '<p><b>Read:</b> <code>mirror/</code>. <b>Write:</b> <code>work/</code>. <b>Mock:</b> <code>mock/kolmafia-mock/</code>.</p>'
      echo '<p><a style="color:#76b7ff" href="../../index.html5">← top-level sandbox index</a></p>'
      echo '</body></html>'
    } > "$BRANCH_ROOT/README.html5"
  fi
fi

# Mirror only code-oriented KoLmafia surfaces. Never mirror account/session material.
# Existing mirrors are intentionally read-only, so thaw owner write permission
# before replacing them, then freeze the fresh copy again.
for d in scripts relay ccs; do
  if [[ -e "$MIRROR_DIR/$d" ]]; then
    chmod -R u+w "$MIRROR_DIR/$d" 2>/dev/null || true
    chmod u+w "$MIRROR_DIR" 2>/dev/null || true
    rm -rf "$MIRROR_DIR/$d"
  fi

  if [[ -d "$LIVE/$d" ]]; then
    cp -a "$LIVE/$d" "$MIRROR_DIR/$d"
    chmod -R a-w "$MIRROR_DIR/$d" 2>/dev/null || true
  else
    mkdir -p "$MIRROR_DIR/$d"
    chmod -R a-w "$MIRROR_DIR/$d" 2>/dev/null || true
  fi
done

printf '%s\n' "$LIVE" > "$BRANCH_ROOT/LIVE_LOCATION.txt"
printf '%s\n' "$BRANCH_ROOT" > "$BRANCH_ROOT/SANDBOX_LOCATION.txt"

cat > "$BRANCH_ROOT/AGENT_BOUNDARY.txt" <<'EOF'
SANDBOX ONLY

mirror/ is a read-only copy.
work/ is writable.
mock/ contains test infrastructure.

NEVER copy or expose:
- settings/
- sessions/
- cookies
- password hashes
- login/session material

A mock/test failure is not permission to fall through to live KoLmafia.
EOF

if [[ ! -d "$MOCK_DIR/.git" ]]; then
  git clone https://github.com/loathers/kolmafia-mock.git "$MOCK_DIR"
fi

if [[ -n "$(git -C "$MOCK_DIR" status --porcelain)" ]]; then
  echo "kolmafia-mock clone is dirty; refusing to change its ref: $MOCK_DIR" >&2
  exit 3
fi

git -C "$MOCK_DIR" fetch --tags origin
git -C "$MOCK_DIR" checkout --detach "$MOCK_REF"

MOCK_INSTALL_STATUS="skipped"
MOCK_INSTALL_EXIT=0
MOCK_TEST_STATUS="skipped"
MOCK_TEST_EXIT=0
MOCK_TEST_REASON="not-run"
MOCK_INSTALL_LOG="$BRANCH_ROOT/logs/kolmafia-mock-install.log"
MOCK_TEST_LOG="$BRANCH_ROOT/logs/kolmafia-mock-tests.log"

if [[ "$DO_INSTALL" -eq 1 ]]; then
  YARN_CMD=()
  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
    YARN_CMD=(corepack yarn)
  elif command -v yarn >/dev/null 2>&1; then
    YARN_CMD=(yarn)
  fi

  if [[ "${#YARN_CMD[@]}" -eq 0 ]]; then
    MOCK_INSTALL_STATUS="unavailable"
    MOCK_TEST_STATUS="skipped"
    MOCK_TEST_REASON="yarn-or-corepack-not-found"
    echo "WARN: Yarn/Corepack not found. Mock source was cloned; dependency install/tests skipped." >&2
  else
    if (
      cd "$MOCK_DIR"
      "${YARN_CMD[@]}" install --immutable
    ) >"$MOCK_INSTALL_LOG" 2>&1; then
      MOCK_INSTALL_STATUS="pass"
    else
      MOCK_INSTALL_EXIT=$?
      MOCK_INSTALL_STATUS="fail"
    fi
    cat "$MOCK_INSTALL_LOG"

    if [[ "$MOCK_INSTALL_STATUS" == "pass" ]]; then
      if (
        cd "$MOCK_DIR"
        "${YARN_CMD[@]}" vitest run
      ) >"$MOCK_TEST_LOG" 2>&1; then
        MOCK_TEST_STATUS="pass"
        MOCK_TEST_REASON="tests-passed"
      else
        MOCK_TEST_EXIT=$?
        MOCK_TEST_STATUS="fail"
        if grep -q 'Cannot POST /graphql' "$MOCK_TEST_LOG"; then
          MOCK_TEST_REASON="upstream-data-of-loathing-v2-graphql-retired"
        else
          MOCK_TEST_REASON="upstream-test-failure"
        fi
      fi
      cat "$MOCK_TEST_LOG"
    else
      MOCK_TEST_STATUS="skipped"
      MOCK_TEST_REASON="dependency-install-failed"
    fi
  fi
else
  MOCK_TEST_REASON="--no-install"
fi

MOCK_HEAD="$(git -C "$MOCK_DIR" rev-parse HEAD)"

cat > "$BRANCH_ROOT/sandbox-manifest.json" <<EOF
{
  "schema": "kolmafia-agent-sandbox/v1",
  "branch": "$SAFE_BRANCH",
  "live_location": "$LIVE",
  "sandbox_location": "$BRANCH_ROOT",
  "mock_repository": "https://github.com/loathers/kolmafia-mock.git",
  "mock_ref_requested": "$MOCK_REF",
  "mock_commit": "$MOCK_HEAD",
  "mock_install_status": "$MOCK_INSTALL_STATUS",
  "mock_install_exit": $MOCK_INSTALL_EXIT,
  "mock_test_status": "$MOCK_TEST_STATUS",
  "mock_test_exit": $MOCK_TEST_EXIT,
  "mock_test_reason": "$MOCK_TEST_REASON",
  "mock_install_log": "logs/kolmafia-mock-install.log",
  "mock_test_log": "logs/kolmafia-mock-tests.log",
  "mirrored_live_dirs": ["scripts", "relay", "ccs"],
  "excluded_live_state": ["settings", "sessions", "cookies", "password hashes", "login/session material"]
}
EOF

# Top-level HTML index.
mkdir -p "$ROOT"
cat > "$ROOT/index.html5" <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KoL Agent Sandbox Index</title>
<style>:root{color-scheme:dark}body{margin:0;background:#090d12;color:#e9f0fa;font:15px/1.5 system-ui,sans-serif}.app{max-width:1100px;margin:auto;padding:24px}.card{background:#111923;border:1px solid #29394d;border-radius:14px;padding:18px;margin:12px 0}a{color:#76b7ff}code{background:#0a1119;border:1px solid #24354a;border-radius:6px;padding:2px 5px}</style></head>
<body><main class="app">
<div class="card"><h1>KoL Agent Sandbox</h1><p>Branch: <a href="sandboxes/$SAFE_BRANCH/README.html5"><code>$SAFE_BRANCH</code></a></p></div>
<div class="card"><h2>Live</h2><code>$LIVE</code><h2>Sandbox</h2><code>$BRANCH_ROOT</code></div>
<div class="card"><h2>Mock</h2><code>loathers/kolmafia-mock @ $MOCK_HEAD</code><p>install: <code>$MOCK_INSTALL_STATUS</code> · tests: <code>$MOCK_TEST_STATUS</code> · reason: <code>$MOCK_TEST_REASON</code></p></div>
</main></body></html>
EOF

if [[ ! -f "$ROOT/README.html5" ]]; then
  cp "$ROOT/index.html5" "$ROOT/README.html5"
else
  decorate_readme "$ROOT/README.html5" || true
fi

echo
echo "SANDBOX READY"
echo "  index:    $ROOT/index.html5"
echo "  branch:   $BRANCH_ROOT"
echo "  live:     $LIVE"
echo "  mock:     $MOCK_DIR @ $MOCK_HEAD"
echo "  install:  $MOCK_INSTALL_STATUS (exit $MOCK_INSTALL_EXIT)"
echo "  tests:    $MOCK_TEST_STATUS (exit $MOCK_TEST_EXIT; $MOCK_TEST_REASON)"
echo "  writable: $WORK_DIR"
if [[ "$MOCK_TEST_STATUS" == "fail" ]]; then
  echo
  echo "NOTE: sandbox creation succeeded even though upstream mock tests failed."
  echo "      See: $MOCK_TEST_LOG"
fi
