# quickgui-skills

Agent skills for building desktop apps with [QuickGUI](https://github.com/egoist/quickgui), the GPU-rendered native GUI framework for Go, TypeScript, and Rust.

The skill content is summarized from the upstream source, docs, and examples by [Cursor Agent](https://cursor.com/docs/cli/overview) and is refreshed automatically after every upstream release.

## Install

Install with the [skills](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add loosheng/quickgui-skills
```

Common variants:

```bash
# List the skills in this repository
npx skills add loosheng/quickgui-skills --list

# Install globally for specific agents without prompts
npx skills add loosheng/quickgui-skills -g -a cursor -a claude-code -y

# Pull the latest version after an upstream release
npx skills update quickgui
```

## Contents

```text
skills/quickgui/
  SKILL.md          # overview, core rules, index of references
  references/       # one file per module (components, styling, reactivity, ...)
```

The agent loads `SKILL.md` first and opens individual reference files only when a task needs them.

`.upstream-version` records the QuickGUI release the skill was last synced to.

## How updates work

`.github/workflows/sync-quickgui.yml` runs every 6 hours (or manually):

1. Reads the latest `egoist/quickgui` release and compares it with `.upstream-version`.
2. If there is a new tag, `scripts/sync.sh` clones upstream at that tag, writes release notes and the diff since the previous synced tag into a temp context file, then runs `cursor-agent --model cursor-grok-4.6-high` with [`prompts/sync-skill.md`](prompts/sync-skill.md).
3. The agent may only edit `skills/`; `.cursor/cli.json` denies git, gh, and writes elsewhere.
4. `scripts/validate.sh` checks the result, and the workflow opens a pull request for review.

### Setup for forks

```bash
gh secret set CURSOR_API_KEY --repo <owner>/quickgui-skills --body "$CURSOR_API_KEY"
```

Then enable **Settings -> Actions -> General -> Allow GitHub Actions to create and approve pull requests**.

### Run locally

```bash
# Full summary for a tag (no previous tag)
scripts/sync.sh v0.1.6

# Incremental update from the previously synced tag
scripts/sync.sh v0.1.7 v0.1.6

scripts/validate.sh
```

Requires `git`, `gh`, `node`, and `cursor-agent` (`curl https://cursor.com/install -fsS | bash`).

## License

MIT
