#!/usr/bin/env bash
set -euo pipefail

ROOT="./kolmafia"
BRANCH=""
WATERSHEEP_URL=""
LIVE_RUNTIME=""
SAMPLES_PER_CLASS=8
ORDER_CHECK=0
RUN_CLIENT_TESTS=0

usage() {
  cat <<'EOF'
Usage:
  run-don-combo-watersheep-lab.sh [options]

Options:
  --root PATH             sandbox top level (default: ./kolmafia)
  --branch NAME           sandbox branch/name (default: current git branch or main)
  --watersheep URL        run WaterSheep benchmark after substrate smoke
  --live-runtime PATH     explicitly compare against a live/exported runtime contract
  --samples-per-class N   labeled scenarios per class (default: 8)
  --order-check           add one cyclic option-order robustness pass
  --client-tests          rerun tokens-of-loathing client unit tests too
  -h, --help              show help

This helper never falls through to live KoLmafia. A live runtime is read only
when --live-runtime is explicitly supplied.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --watersheep) WATERSHEEP_URL="$2"; shift 2 ;;
    --live-runtime) LIVE_RUNTIME="$2"; shift 2 ;;
    --samples-per-class) SAMPLES_PER_CLASS="$2"; shift 2 ;;
    --order-check) ORDER_CHECK=1; shift ;;
    --client-tests) RUN_CLIENT_TESTS=1; shift ;;
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
TOKENS_DIR="$BRANCH_ROOT/mock/tokens-of-loathing"
MOCK_DIR="$BRANCH_ROOT/mock/kolmafia-mock"
LAB_DIR="$BRANCH_ROOT/work/don-combo-watersheep-lab"
ENTRYPOINT="$TOKENS_DIR/compat/don-combo-watersheep/materialize.sh"

if [[ ! -d "$BRANCH_ROOT" ]]; then
  echo "Sandbox does not exist: $BRANCH_ROOT" >&2
  echo "Run bootstrap-agent-sandbox.sh first." >&2
  exit 3
fi

if [[ ! -x "$ENTRYPOINT" && ! -f "$ENTRYPOINT" ]]; then
  echo "Pinned tokens-of-loathing checkout does not contain the don_combo WaterSheep lab." >&2
  echo "Re-bootstrap the sandbox with a tokens ref that includes compat/don-combo-watersheep/." >&2
  exit 3
fi

if [[ ! -d "$MOCK_DIR/.git" ]]; then
  echo "Verified mock checkout is missing: $MOCK_DIR" >&2
  echo "Re-bootstrap the sandbox before running the lab." >&2
  exit 3
fi

ARGS=(
  --lab-dir "$LAB_DIR"
  --mock-dir "$MOCK_DIR"
  --samples-per-class "$SAMPLES_PER_CLASS"
)

if [[ "$RUN_CLIENT_TESTS" -eq 0 ]]; then
  ARGS+=(--skip-client-tests)
fi
if [[ -n "$WATERSHEEP_URL" ]]; then
  ARGS+=(--watersheep "$WATERSHEEP_URL")
fi
if [[ -n "$LIVE_RUNTIME" ]]; then
  ARGS+=(--live-runtime "$LIVE_RUNTIME")
fi
if [[ "$ORDER_CHECK" -eq 1 ]]; then
  ARGS+=(--order-check)
fi

echo "== don_combo WaterSheep sandbox lab =="
echo "sandbox=$BRANCH_ROOT"
echo "tokens=$TOKENS_DIR"
echo "mock=$MOCK_DIR"
echo "lab=$LAB_DIR"
if [[ -n "$LIVE_RUNTIME" ]]; then
  echo "live_runtime=$LIVE_RUNTIME (explicit read-only input)"
else
  echo "live_runtime=not-supplied"
fi

bash "$ENTRYPOINT" "${ARGS[@]}"

echo
echo "SANDBOX_WATERSHEEP_LAB=PASS"
echo "manifest=$LAB_DIR/lab-manifest.json"
if [[ -f "$LAB_DIR/results/report.json" ]]; then
  echo "report=$LAB_DIR/results/report.json"
fi
