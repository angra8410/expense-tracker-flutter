@echo off
chcp 65001 >nul
echo ⚡ Starting Expense Tracker...

REM Get the directory where this .bat file is located
set PROJECT_DIR=%~dp0

REM Check if we're in the right place
if not exist "%PROJECT_DIR%pubspec.yaml" (
    echo ❌ Error: pubspec.yaml not found!
    echo Please put this .bat file in your Flutter project folder
    pause
    exit
)

REM Change to project directory
cd /d "%PROJECT_DIR%"

REM Check if already running
netstat -an | find "3000" | find "LISTENING" >nul
if %ERRORLEVEL% EQU 0 (
    echo 📱 Server already running, opening browser...
    start http://localhost:3000
    timeout /t 2 /nobreak >nul
    exit
)

REM Start Flutter server in background
echo 🚀 Starting Flutter server...
start /B flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000

REM Wait for server to start and open browser
echo ⏳ Waiting for server...
timeout /t 10 /nobreak >nul
start http://localhost:3000
echo ✅ Expense Tracker opened!
timeout /t 3 /nobreak >nul
exit