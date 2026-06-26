# CLAUDE.md — standing instructions for Claude in this repo

## Clipboard delivery — ALWAYS push commands/config to the destination machine's clipboard

When a reply contains any command or config block the user must paste somewhere, deliver it
**directly onto the destination machine's clipboard in the same turn**. Do NOT make the user
copy-paste across machines (Mouse Without Borders' clipboard sync mangles rich text), and do
NOT ask each time. Push multiple snippets as **separate Win+V clipboard-history entries**.

- **Destination: PC3, always.** PC3 is the dedicated terminal box — the user reaches
  PC1-WSL, PC1-Windows, PC2, and the nodes all through Termius on PC3, so everything
  pasted goes into a PC3 Termius session → push to **PC3**. (Only exception: a command
  that must run in a *local elevated PowerShell* on PC1/PC2, not via Termius.)
  State item count.
- **Mechanism + `Push-Clip`:** [`ops/access/codex-clipboard-prompt.md`](ops/access/codex-clipboard-prompt.md).
  Persistent `Aurora-SetClipboard` task on PC1/PC2/PC3; stage `C:\ProgramData\Aurora\clip.txt`
  (items joined by a line `===AURORA-CLIP-SEP===`), then `Start-ScheduledTask`. PC1 local;
  PC2/PC3 via `ssh pc2`/`ssh pc3`.
- Only push pasteable text; keystrokes stay as written steps. For IOS-XR router consoles,
  inject config directly (iolcfg / tmux send-keys) to avoid bracketed-paste markers.

(Broader lab context lives in Claude's project memory; this file is the repo-versioned
reinforcement of the clipboard rule.)
