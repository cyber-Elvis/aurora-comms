' Aurora: run the MWB keep-alive with no console window.
' wscript creates no window; Run(...,0,False) launches PowerShell hidden (style 0).
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\ProgramData\Aurora\mwb-keepalive.ps1""", 0, False
