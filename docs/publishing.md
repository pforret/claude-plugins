# Publishing fodo

Fodo is distributed two ways: through this repo's own marketplace (`pforret-todo`) and through
Anthropic's plugin directory. Both read `plugins/fodo/` from GitHub `pforret/ClaudePluginTodo`.

## Release checklist

1. Bump `version` in `plugins/fodo/.claude-plugin/plugin.json`. Users of the own marketplace only
   receive an update when this string changes.
2. Remove macOS litter, which the directory blocks: `find plugins -name .DS_Store -delete`
3. Check:
   ```bash
   shellcheck plugins/fodo/scripts/*.sh
   php -l plugins/fodo/dashboard/index.php
   bats tests/
   claude plugin validate --strict plugins/fodo
   claude plugin validate --strict .
   ```
4. Commit and push to `main`.
5. Own marketplace: users run `claude plugin update fodo@pforret-todo` (or have auto-update on).
6. Directory: the portal picks up the new commit and scans it (see below).

## Anthropic plugin directory

Requires a paid claude.ai plan. Steps from https://claude.com/docs/plugins/submit:

1. Open https://claude.ai/directory/manage → **Submit new** → **Plugin bundle**.
2. Source: repository `pforret/ClaudePluginTodo`, plugin path `plugins/fodo`, branch `main`.
3. Select **Validate**. Fix every finding marked **Blocking**, push, then **Re-validate**.
4. Submit. After approval, choose when to publish.

Rules worth re-checking before each submission
(https://claude.com/docs/plugins/pre-submission-checklist):

- `README.md` (at least 40 words outside code blocks) and `LICENSE` in `plugins/fodo/`.
- No `.DS_Store`, symlinks, `.ico` or other binaries besides PNG/JPEG/GIF/WebP/SVG/fonts.
- Every non-image file under 256 KiB, at most 512 files.
- Valid YAML frontmatter with a string `description` in every `SKILL.md`.
- The README's "What this plugin runs and writes" section matches what the code does. The
  security scan rejects undisclosed behaviour.
- The plugin name `fodo` is permanent once submitted. Change `displayName` instead.
