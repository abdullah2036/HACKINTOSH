@echo off
rem Read-only check of the SSD's EFI partition and UEFI boot entries.
rem Asks for administrator rights itself. Writes esp_check_log.txt next to this file.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "LOG=%~dp0esp_check_log.txt"
echo ==== %date% %time% > "%LOG%"

mountvol Z: /S >> "%LOG%" 2>&1
echo ---- Z:\EFI >> "%LOG%"
dir /b Z:\EFI >> "%LOG%" 2>&1
echo ---- Z:\EFI\BOOT >> "%LOG%"
dir /b Z:\EFI\BOOT >> "%LOG%" 2>&1
echo ---- Z:\EFI\OC >> "%LOG%"
dir /b Z:\EFI\OC >> "%LOG%" 2>&1
echo ---- Z:\EFI\OC\Kexts >> "%LOG%"
dir /b Z:\EFI\OC\Kexts >> "%LOG%" 2>&1
echo ---- Z:\EFI\OC\Drivers >> "%LOG%"
dir /b Z:\EFI\OC\Drivers >> "%LOG%" 2>&1
echo ---- Z:\EFI\OC\ACPI >> "%LOG%"
dir /b Z:\EFI\OC\ACPI >> "%LOG%" 2>&1
copy /y Z:\EFI\OC\config.plist "%~dp0esp_config.plist" >> "%LOG%" 2>&1
mountvol Z: /D >> "%LOG%" 2>&1

echo ---- firmware boot entries >> "%LOG%"
bcdedit /enum firmware >> "%LOG%" 2>&1

echo.
echo Done. Tell Claude it finished. You can close this window.
pause
