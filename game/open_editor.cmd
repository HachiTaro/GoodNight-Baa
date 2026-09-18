@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot_task.ps1" -Task editor
if errorlevel 1 pause
