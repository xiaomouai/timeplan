@echo off
setlocal EnableExtensions

cd /d "%~dp0"
set "VENV_DIR=%CD%\.venv"

if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo [1/4] Creating Python virtual environment...
    where py >nul 2>&1
    if not errorlevel 1 (
        py -3 -m venv "%VENV_DIR%"
    ) else (
        where python >nul 2>&1
        if errorlevel 1 goto :python_missing
        python -m venv "%VENV_DIR%"
    )
    if errorlevel 1 goto :failed
)

call "%VENV_DIR%\Scripts\activate.bat"
if errorlevel 1 goto :failed

if not exist ".env" (
    echo [2/4] Creating local .env from .env.example...
    copy /Y ".env.example" ".env" >nul
    if errorlevel 1 goto :failed
)

if not exist "%VENV_DIR%\.requirements-installed" (
    echo [3/4] Installing backend dependencies...
    python -m pip install --upgrade pip
    if errorlevel 1 goto :failed
    python -m pip install -r requirements.txt
    if errorlevel 1 goto :failed
    type nul > "%VENV_DIR%\.requirements-installed"
)

if not exist "instance" mkdir "instance"
if not exist "logs" mkdir "logs"
if not exist "uploads" mkdir "uploads"
set "PYTHONPATH=%CD%"

echo [4/4] Starting Xueba API at http://localhost:5000 ...
echo Health: http://localhost:5000/health
echo Docs:   http://localhost:5000/api/docs
echo Press Ctrl+C to stop.
python app.py
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo API exited with code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%

:python_missing
echo Python 3 was not found. Install Python 3.11+ and enable "Add python.exe to PATH".
pause
exit /b 1

:failed
echo Local API startup failed. Read the error above, then retry this file.
pause
exit /b 1
