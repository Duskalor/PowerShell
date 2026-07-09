' Lanza autosync.ps1 sin crear ninguna ventana de consola visible.
' pwsh -WindowStyle Hidden igual crea la ventana y despues la oculta (flash).
' WScript.Shell.Run con windowStyle 0 nunca la crea.

Set objShell = CreateObject("WScript.Shell")
scriptPath = """C:\Users\Paul Cruz\Documents\PowerShell\engram-sync\autosync.ps1"""
objShell.Run "pwsh -NoProfile -ExecutionPolicy Bypass -File " & scriptPath, 0, True
