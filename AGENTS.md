# AGENTS.md — standing instructions for AI agents (Codex et al.) in this repo

## Clipboard delivery — ALWAYS push commands/config to the destination machine's clipboard

When a reply contains any command or config block the user must paste somewhere, deliver it
**directly onto the destination machine's clipboard in the same turn**. Do NOT make the user
copy-paste across machines (Mouse Without Borders' clipboard sync mangles rich text), and do
NOT ask each time. Push multiple snippets as **separate Win+V clipboard-history entries** so
the user opens `Win+V` and pastes each in turn.

- **Destination:** node config / anything pasted in Termius → **PC3** (default); PC2-specific
  → **PC2**; PC1-specific → **PC1**. Always state which machine + item count
  ("On PC3's clipboard (N items) — Win+V and paste each").
- **Mechanism + reusable `Push-Clip` function:** see [`ops/access/codex-clipboard-prompt.md`](ops/access/codex-clipboard-prompt.md).
  Persistent `Aurora-SetClipboard` task on PC1/PC2/PC3: stage text into
  `C:\ProgramData\Aurora\clip.txt` (multiple items joined by a line containing only
  `===AURORA-CLIP-SEP===`), then `Start-ScheduledTask Aurora-SetClipboard`. PC1 is local;
  PC2/PC3 via `ssh pc2` / `ssh pc3`.
- Only push **pasteable text**; keystroke instructions (e.g. "Ctrl+B then D") stay as written
  steps. For **IOS-XR router consoles**, inject config directly (iolcfg / tmux send-keys)
  rather than pasting, to avoid bracketed-paste (`^[[200~`) markers.
