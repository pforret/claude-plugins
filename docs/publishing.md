# Publishing fodo

Fodo is distributed two ways: through this repo's own marketplace (`pforret-claude`) and through
Anthropic's plugin directory. Both read `plugins/fodo/` from GitHub `pforret/claude-plugins`.

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
5. Own marketplace: users run `claude plugin update fodo@pforret-claude` (or have auto-update on).
6. Directory: the portal picks up the new commit and scans it (see below).

## Anthropic plugin directory

Docs: https://claude.com/docs/directory/publish and https://claude.com/docs/plugins/submit.
The listing lives in the developer portal at https://claude.ai/directory/manage.

### Before the first submission

- **Plan and organization:** you need a Pro, Max, Team or Enterprise plan. The organization you
  submit from owns the listing. The first organization to submit `pforret/claude-plugins` +
  `plugins/fodo` holds that folder for good.
- **GitHub:** connect your GitHub account to claude.ai in that organization. The portal checks
  that the account can push to `pforret/claude-plugins`. The repo is public, so the Claude GitHub
  App and the private-source upload are not needed.
- **Code on GitHub:** the commit you want listed must be pushed to `main`, because the portal
  validates the newest commit there.
- **Local check:** run the release checklist above. The portal's **Validate** runs more checks than
  `claude plugin validate`.

### Submit (one submission per plugin folder)

1. https://claude.ai/directory/manage → **Submit new** → **Plugin bundle**.
2. **Source**:
   - **Repository**: `pforret/claude-plugins`
   - **Plugin path**: `plugins/fodo`
   - **Branch or tag**: `main`, or leave it empty for the default branch. This is the *tracked
     branch*.

   Select **Validate**, fix every blocking finding, push, then **Validate** again. A result is
   only valid for one commit.
3. **Listing details**: this preview is read from `plugin.json` and the README. To change it, edit
   those files, push and validate again.
4. **Data handling**: does it read or store personal data? → no. Does it send data to other
   services? → no. Data retention → files stay in your repo and `~/.claude/todo/`. For people
   under 18? → no.
5. **Compliance**: check the contact email and tick all four acknowledgements.
6. **Review and submit**:
   - Under **How new versions reach the directory**, keep **GitHub push webhook**.
   - Optionally turn on **Auto-publish passing versions**.
   - Select **Submit for review**. Then choose **Set up push updates**, which needs admin rights on
     the repo.

### After submitting

- Each version gets validation plus a security scan, and a person reviews the first listing.
  Possible results:
  - **passes**: it can be published
  - **held for a reviewer**: it waits for review
  - **doesn't pass**: the portal lists the broken rules
- Follow it under **Submissions** in the portal; the **Versions** tab shows each scanned commit.
- Fixing a failed version:
  - If it was not rejected: push the fix, then **Check for new commits**.
  - If it was rejected: read **Requested changes** on the **Review** tab, push the fix, then
    **Resubmit for review**.
- A passing version is not live until you select **Publish**. By default a reviewer then
  publishes it; the **Auto-publish** row on the **Overview** tab shows which setting applies.
- Updates: merge to `main` and raise `version` in `plugin.json`. The directory picks up the commit
  through the webhook or its schedule, scans it, and publishes according to the publish setting.
  The listing keeps serving the last published version until a newer one passes.
- Limits:
  - 10 submissions per organization per 24 h, drafts and withdrawals included.
  - One submission per repo + folder.
  - The repo and folder can't be changed after submitting.
- Withdrawing:
  - **Delete draft**: before submitting.
  - **Withdraw submission**: in review, never published.
  - **Delist plugin**: live. Installed copies stop getting updates.
- The listing can appear in claude.ai chat and Cowork as well as Claude Code. Fodo needs a local
  repo, bash and git, so the README says it only works in Claude Code.

Rules worth re-checking before each submission
(https://claude.com/docs/plugins/pre-submission-checklist):

- `README.md` (at least 40 words outside code blocks) and `LICENSE` in `plugins/fodo/`.
- No `.DS_Store`, symlinks, `.ico` or other binaries besides PNG/JPEG/GIF/WebP/SVG/fonts.
- Every non-image file under 256 KiB, at most 512 files.
- Valid YAML frontmatter with a string `description` in every `SKILL.md`.
- The README's "What this plugin runs and writes" section matches what the code does. The
  security scan rejects undisclosed behaviour.
- The plugin name `fodo` is permanent once submitted. Change `displayName` instead.

## buildwithclaude.com

https://www.buildwithclaude.com lists community marketplaces automatically. Its crawler
(`web-ui/lib/indexer/marketplace-indexer.ts` in `davepoon/buildwithclaude`) finds public, non-fork
repos in two ways:

- by searching GitHub code for `filename:marketplace.json path:.claude-plugin`;
- by repository topics such as `claude-code-plugins` and `claude-code-skills`.

Nothing to submit: push to `main`, and optionally add the topics:
`gh repo edit pforret/claude-plugins --add-topic claude-code-plugins,claude-code-skills`.

The alternative is a PR that copies the plugin into their repo, so users install it as
`fodo@buildwithclaude`:

- Follow https://github.com/davepoon/buildwithclaude/blob/main/CONTRIBUTING.md: fork, copy to
  `plugins/fodo/`, run `npm test`, use branch `add-fodo` and PR title "Add fodo plugin".
- Their guide only covers agents, commands and hooks inside plugins, and the copy would need a PR
  for every release. Not recommended.

## Known directory holds (first Validate, 2026-10-23)

- **Image or font file that the plugin's code could run** (`UNREAD_ASSET_REFERENCED`): the
  validator does not read PNGs as code, so code that names a PNG holds the plugin. Here that was
  `index.php` (favicon, apple-touch-icon) and `manifest.json` (PWA icons). SVGs are read as text and
  pass. Fix: the dashboard only uses `icon.svg` and `laravel.svg`; the PNGs and `manifest.json`
  are gone. Keep code from naming PNG/JPG/font files. `.claude-plugin/icon.png` is fine because
  nothing references it.
- **Uses a credential from the user's machine** (`MCP_FORWARDS_CREDENTIAL_ENV`): the scanner
  pairs the reads under `~/.claude/` with anything in `index.php` that could send data. First that
  was the `http://` literal in the `/config` same-origin check, now `parse_url('//' . HTTP_HOST)`.
  Then it was the `fetch()` of the 15-second partial refresh, now replaced by
  `<meta http-equiv="refresh" content="60">`, which reloads the whole page and is left off `/config`.
  Keep `fetch`, `XMLHttpRequest` and `http://` out of the dashboard.
  After that it flagged ordinary shell syntax in `todo.sh` (`${x:-$y}`, then `IFS=$'\t'`). Its
  "send" detector matches harmless code, so the hold is **left for the reviewer**: nothing in fodo
  sends data off the machine, and the README says so.
- **Name may be confused with an existing listing** (`NAME_CONFUSABLE`): `fodo` resembles the
  connector publisher "Nodo" and the plugin "Qodo" (qodo-ai/qodo-skills). The name was kept on
  purpose; the reviewer decides.
- **Unrecognized field in plugin.json** (`UNKNOWN_KEY`, warning ×4): `documentationUrl`, `supportUrl`,
  `privacyPolicyUrl` and `termsOfServiceUrl` are only read by the directory, for the listing's Links
  section; Claude Code ignores them. Expected, no action.
