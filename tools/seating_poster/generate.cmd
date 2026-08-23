@echo off
setlocal
cd /d "%~dp0"

if not exist node_modules (
  call "%ProgramFiles%\nodejs\npm.cmd" install --no-audit --no-fund
  if errorlevel 1 exit /b %errorlevel%
)

node generate.js
