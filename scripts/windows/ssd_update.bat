@echo off
rem Copies Hackintosh_Build\EFI_daily\OC to the SSD as EFI\OC (normal boot) and
rem Hackintosh_Build\EFI_safe\OC as EFI\OCSAFE (no graphics driver), and adds an
rem "OpenCore Safe Mode" boot entry. Asks for administrator rights itself.
rem Writes ssd_update_log.txt next to this file.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "HERE=%~dp0"
set "LOG=%HERE%ssd_update_log.txt"
set "DAILY=%HERE%Hackintosh_Build\EFI_daily\OC"
set "SAFE=%HERE%Hackintosh_Build\EFI_safe\OC"
echo ==== %date% %time% > "%LOG%"

if not exist "%DAILY%\OpenCore.efi" (
  echo ERROR: %DAILY% is missing. >> "%LOG%"
  goto fail
)
if not exist "%SAFE%\OpenCore.efi" (
  echo ERROR: %SAFE% is missing. >> "%LOG%"
  goto fail
)
echo ---- Daily kexts: >> "%LOG%"
dir /b "%DAILY%\Kexts" >> "%LOG%" 2>&1

echo ---- 1. Backing up boot entries and the EFI partition >> "%LOG%"
bcdedit /export "%HERE%bcd_backup_update" >> "%LOG%" 2>&1
if errorlevel 1 goto fail
mountvol Z: /S >> "%LOG%" 2>&1
if not exist Z:\EFI\OC\OpenCore.efi (
  echo ERROR: could not open the EFI partition or EFI\OC is missing. >> "%LOG%"
  goto unmount_fail
)
robocopy Z:\EFI "%HERE%esp_backup_update\EFI" /E /NFL /NDL /NJH /NJS >> "%LOG%" 2>&1

echo ---- 2. Updating EFI\OC (normal) and EFI\OCSAFE (safe mode) >> "%LOG%"
robocopy "%DAILY%" Z:\EFI\OC /MIR /NFL /NDL /NJH /NJS >> "%LOG%" 2>&1
if errorlevel 8 goto unmount_fail
robocopy "%SAFE%" Z:\EFI\OCSAFE /MIR /NFL /NDL /NJH /NJS >> "%LOG%" 2>&1
if errorlevel 8 goto unmount_fail
echo ---- SSD kexts now: >> "%LOG%"
echo [EFI\OC] >> "%LOG%"
dir /b Z:\EFI\OC\Kexts >> "%LOG%" 2>&1
echo [EFI\OCSAFE] >> "%LOG%"
dir /b Z:\EFI\OCSAFE\Kexts >> "%LOG%" 2>&1
mountvol Z: /D >> "%LOG%" 2>&1

echo ---- 3. Safe Mode boot entry >> "%LOG%"
bcdedit /enum firmware | find /i "OpenCore Safe Mode" >nul
if not errorlevel 1 (
  echo Safe Mode entry already exists. >> "%LOG%"
  goto done
)
set "SAFEID="
for /f "tokens=2 delims={}" %%g in ('bcdedit /copy {bootmgr} /d "OpenCore Safe Mode"') do set "SAFEID={%%g}"
if not defined SAFEID (
  echo ERROR: could not create the Safe Mode entry. >> "%LOG%"
  goto fail
)
echo New entry: %SAFEID% >> "%LOG%"
bcdedit /set %SAFEID% path \EFI\OCSAFE\OpenCore.efi >> "%LOG%" 2>&1
bcdedit /set {fwbootmgr} displayorder %SAFEID% /addlast >> "%LOG%" 2>&1

:done
echo ---- Boot order now: >> "%LOG%"
bcdedit /enum {fwbootmgr} >> "%LOG%" 2>&1
echo RESULT: OK >> "%LOG%"
echo.
echo Done. Tell Claude it finished. You can close this window.
pause
exit /b

:unmount_fail
mountvol Z: /D >> "%LOG%" 2>&1
:fail
echo RESULT: FAILED >> "%LOG%"
echo.
echo Something went wrong. Tell Claude so it can read the log.
pause
exit /b 1
