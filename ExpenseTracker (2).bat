@echo off
chcp 65001 >nul
cls
echo ================================================
echo    🚀 EXPENSE TRACKER - angra8410  
echo    📊 2025-07-06 05:50 UTC - Port Fix
echo ================================================
echo.

cd /d "C:\Projects\flutter-docker\expense_tracker"

echo 🌐 Starting Flutter server on port 3000...
echo 📱 Will open at: http://localhost:3000
echo.

REM Use port 3000 to match browser expectation
flutter run -d web-server --web-hostname localhost --web-port 3000 --release

pause