' Hidden launcher for set-clip.ps1 (window style 0 = no console flash).
' Used by the on-demand scheduled task Aurora-SetClipboard so the clipboard is set
' in the console user's interactive session.
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""C:\ProgramData\Aurora\set-clip.ps1""", 0, False
