#!/usr/bin/env bash
# Usage: scripts/sync.sh <tag> [prev-tag]
#
# Clones egoist/quickgui at <tag>, prepares sync context, and runs Cursor Agent
# to write (no prev-tag) or update (with prev-tag) skills/quickgui.
#
# Environment:
#   UPSTREAM_REPO   default: egoist/quickgui
#   SYNC_WORK_DIR   default: ${RUNNER_TEMP:-${TMPDIR:-/tmp}}/quickgui-sync
#   AGENT_MODEL     default: cursor-grok-4.6-high
#   CURSOR_API_KEY  required in CI; locally `cursor-agent login` also works
set -euo pipefail

TAG="${1:?usage: scripts/sync.sh <tag> [prev-tag]}"
PREV_TAG="${2:-}"
UPSTREAM_REPO="${UPSTREAM_REPO:-egoist/quickgui}"
AGENT_MODEL="${AGENT_MODEL:-cursor-grok-4.6-high}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
WORK_DIR="${SYNC_WORK_DIR:-${TMP_BASE%/}/quickgui-sync}"
UPSTREAM_DIR="$WORK_DIR/upstream"
CONTEXT_FILE="$WORK_DIR/context.md"
DIFF_FILE="$WORK_DIR/diff.patch"

if [[ -n "$PREV_TAG" ]]; then MODE=incremental; else MODE=full; fi

log() { printf '\033[1;34m[sync]\033[0m %s\n' "$*" >&2; }

command -v cursor-agent >/dev/null || { echo "Cursor CLI 'cursor-agent' not found" >&2; exit 1; }

log "mode=$MODE tag=$TAG prev=${PREV_TAG:-none} model=$AGENT_MODEL"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

log "cloning $UPSTREAM_REPO"
git clone --quiet --filter=blob:none "https://github.com/$UPSTREAM_REPO.git" "$UPSTREAM_DIR"
git -C "$UPSTREAM_DIR" -c advice.detachedHead=false checkout --quiet "refs/tags/$TAG"

# User-facing sources; translations and internals are excluded.
PATHSPEC=(
  AGENTS.md
  README.md
  CHANGELOG.md
  website/src/content/docs
  docs
  examples
  packages/cli/src
  packages/cli/templates
  packages/solid/src
  packages/native/src
  go/ui
  go/native
  go/reactive
  src
  ':(exclude,glob)website/src/content/docs/**/ja/**'
  ':(exclude,glob)website/src/content/docs/**/zh/**'
  ':(exclude)docs/architecture'
  ':(exclude,glob)**/*_test.go'
  ':(exclude,glob)**/*_generated.go'
)

log "writing $CONTEXT_FILE"
{
  echo "# Sync context: $UPSTREAM_REPO $TAG"
  echo
  echo "## Release notes"
  echo
  gh release view "$TAG" -R "$UPSTREAM_REPO" --json body -q .body 2>/dev/null || echo "(unavailable)"
  echo
  if [[ "$MODE" == incremental ]]; then
    echo "## Changed user-facing files ($PREV_TAG..$TAG)"
    echo
    echo '```text'
    git -C "$UPSTREAM_DIR" diff --stat=200 "refs/tags/$PREV_TAG" "refs/tags/$TAG" -- "${PATHSPEC[@]}"
    echo '```'
    echo
    echo "## CHANGELOG additions"
    echo
    git -C "$UPSTREAM_DIR" diff --unified=0 "refs/tags/$PREV_TAG" "refs/tags/$TAG" -- CHANGELOG.md \
      | grep '^+' | grep -v '^+++' | sed 's/^+//' || true
  else
    echo "## CHANGELOG (latest entries)"
    echo
    head -n 200 "$UPSTREAM_DIR/CHANGELOG.md"
  fi
} >"$CONTEXT_FILE"

if [[ "$MODE" == incremental ]]; then
  log "writing $DIFF_FILE"
  git -C "$UPSTREAM_DIR" diff "refs/tags/$PREV_TAG" "refs/tags/$TAG" -- "${PATHSPEC[@]}" ':(exclude)CHANGELOG.md' >"$DIFF_FILE"
fi

PROMPT="$(cat <<EOF
Runtime:
- UPSTREAM_DIR: $UPSTREAM_DIR
- TAG: $TAG
- PREV_TAG: ${PREV_TAG:-none}
- MODE: $MODE
- CONTEXT_FILE: $CONTEXT_FILE
- DIFF_FILE: $([[ "$MODE" == incremental ]] && echo "$DIFF_FILE" || echo none)
- SKILL_DIR: $REPO_ROOT/skills/quickgui

$(cat "$REPO_ROOT/prompts/sync-skill.md")
EOF
)"

snapshot() {
  git -C "$REPO_ROOT" status --porcelain --untracked-files=all -- . ':(exclude)skills' ':(exclude).upstream-version' 2>/dev/null || true
}
BEFORE="$(snapshot)"

log "running cursor-agent"
(
  cd "$REPO_ROOT"
  cursor-agent -p --force --trust \
    --model "$AGENT_MODEL" \
    --workspace "$REPO_ROOT" \
    --add-dir "$WORK_DIR" \
    --output-format text \
    "$PROMPT"
)

AFTER="$(snapshot)"
if [[ "$BEFORE" != "$AFTER" ]]; then
  echo "cursor-agent modified files outside skills/:" >&2
  diff <(echo "$BEFORE") <(echo "$AFTER") >&2 || true
  exit 1
fi

echo "$TAG" >"$REPO_ROOT/.upstream-version"
log "done; .upstream-version=$TAG"
