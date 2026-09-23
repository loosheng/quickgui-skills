#!/usr/bin/env bash
# Validates every skill under skills/: frontmatter, relative links, and
# discoverability through the `skills` CLI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

errors=0
fail() { echo "error: $*" >&2; errors=$((errors + 1)); }

shopt -s nullglob
skill_files=(skills/*/SKILL.md)
[[ ${#skill_files[@]} -gt 0 ]] || { echo "error: no skills/*/SKILL.md found" >&2; exit 1; }

frontmatter() { awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print}' "$1"; }

for skill in "${skill_files[@]}"; do
  dir="$(dirname "$skill")"
  expected="$(basename "$dir")"
  fm="$(frontmatter "$skill")"
  [[ -n "$fm" ]] || { fail "$skill: missing YAML frontmatter"; continue; }

  name="$(sed -n 's/^name:[[:space:]]*//p' <<<"$fm" | tr -d "\"'" | head -n1)"
  description="$(sed -n 's/^description:[[:space:]]*//p' <<<"$fm" | head -n1)"
  [[ "$name" == "$expected" ]] || fail "$skill: name '$name' must match directory '$expected'"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$skill: name '$name' must be lowercase with hyphens"
  [[ -n "$description" ]] || fail "$skill: missing description"

  lines="$(wc -l <"$skill" | tr -d ' ')"
  [[ "$lines" -le 500 ]] || fail "$skill: $lines lines (limit 500)"

  while IFS= read -r md; do
    md_dir="$(dirname "$md")"
    # Markdown links outside fenced code blocks, excluding URLs and anchors.
    while IFS= read -r target; do
      target="${target%%#*}"
      [[ -z "$target" ]] && continue
      [[ -e "$md_dir/$target" ]] || fail "$md: broken link '$target'"
    done < <(awk '/^[[:space:]]*```/ {code=!code; next} !code' "$md" \
      | grep -oE '\]\([^)[:space:]]+\)' \
      | sed -E 's/^\]\((.*)\)$/\1/' \
      | grep -vE '^(https?:|mailto:|#)' || true)
  done < <(find "$dir" -name '*.md' -type f)
done

if [[ "${SKIP_SKILLS_CLI:-}" != 1 ]]; then
  listed="$(npx -y skills add . --list 2>&1 || true)"
  for skill in "${skill_files[@]}"; do
    name="$(basename "$(dirname "$skill")")"
    grep -qE "[[:space:]]$name[[:space:]]*$" <<<"$listed" || fail "skills CLI does not list '$name':"$'\n'"$listed"
  done
fi

if [[ $errors -gt 0 ]]; then
  echo "$errors error(s)" >&2
  exit 1
fi
echo "ok: ${#skill_files[@]} skill(s) valid"
