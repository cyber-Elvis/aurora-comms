' Aurora: launch the MWB peer-watchdog with no console window (wscript = no window;
' window style 0 = hidden). Eliminates the powershell console flash that the
' scheduled task produced when run as the logged-on user every 2 minutes.
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\Elvis\AppData\Local\Aurora\repair-mwb-peer-sessions.ps1""", 0, False
