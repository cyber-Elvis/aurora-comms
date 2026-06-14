# Node SSH access snippets

These snippets start SSH access for the active Region A core:

| Alias | Node | Platform | Snippet |
| --- | --- | --- | --- |
| `mel-p1` | MEL-P / Aurora-P | Cisco IOL-L3 | `mel-p1-ios-ssh-access.txt` |
| `mel-pe1` | MEL-PE1 / Aurora-PE-1 | Cisco IOL-L3 | `mel-pe1-ios-ssh-access.txt` |
| `bne-pe1` | BNE-PE1 / Aurora-PE-2 | Cisco IOL-L3 | `bne-pe1-ios-ssh-access.txt` |
| `syd-pe1` | SYD-PE1 / Aurora-PE-3 | Cisco IOS-XRv | `syd-pe1-iosxr-ssh-access.txt` |

Use these only after replacing placeholders:

- `<YOU_SET_ADMIN_SECRET_ON_BOX>`
- `<YOU_SET_ENABLE_SECRET_ON_BOX>`
- `<AURORA_CODEX_LOCAL_PUBLIC_KEY_BODY>`
- `<AURORA_CLAUDE_LOCAL_PUBLIC_KEY_BODY>`

The IOL snippets use IOS `ip ssh pubkey-chain`; paste the key body without the `ssh-ed25519` prefix/comment if the CLI requests only the key body. IOS-XR accepts the full public key in its `sshkey` form.

After applying a snippet, test from PC1:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex -IdentityFile $HOME\.ssh\aurora-codex-local-ed25519
```
