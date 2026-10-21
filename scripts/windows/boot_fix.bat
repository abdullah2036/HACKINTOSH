@echo off
rem Makes the SSD boot OpenCore without the USB and removes the Ubuntu leftovers.
rem Asks for administrator rights itself. Writes boot_fix_log.txt next to this file.
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "HERE=%~dp0"
set "LOG=%HERE%boot_fix_log.txt"
set "DAILY=%HERE%Hackintosh_Build\EFI_daily"
set "UBUNTU_ID={557a5c08-ccc2-11f1-a38a-806e6f6e6963}"
echo ==== %date% %time% > "%LOG%"

if not exist "%DAILY%\OC\OpenCore.efi" (
  echo ERROR: %DAILY% is missing. >> "%LOG%"
  goto fail
)

echo ---- 1. Backing up boot entries >> "%LOG%"
bcdedit /export "%HERE%bcd_backup" >> "%LOG%" 2>&1
if errorlevel 1 goto fail

echo ---- 2. Opening the EFI partition and backing it up >> "%LOG%"
mountvol Z: /S >> "%LOG%" 2>&1
if not exist Z:\EFI\Microsoft (
  echo ERROR: could not open the EFI partition. >> "%LOG%"
  goto fail
)
robocopy Z:\EFI "%HERE%esp_backup\EFI" /E /NFL /NDL /NJH /NJS >> "%LOG%" 2>&1
if not exist "%HERE%esp_backup\EFI\Microsoft" (
  echo ERROR: backup failed, nothing was changed. >> "%LOG%"
  goto unmount_fail
)

echo ---- 3. Installing the daily OpenCore on the SSD >> "%LOG%"
xcopy "%DAILY%\OC" Z:\EFI\OC /E /I /Y /Q >> "%LOG%" 2>&1
del /q Z:\EFI\BOOT\fbx64.efi Z:\EFI\BOOT\mmx64.efi >> "%LOG%" 2>&1
copy /y "%DAILY%\BOOT\BOOTx64.efi" Z:\EFI\BOOT\BOOTx64.efi >> "%LOG%" 2>&1

echo ---- 4. Removing the Ubuntu folder >> "%LOG%"
if exist Z:\EFI\ubuntu rmdir /s /q Z:\EFI\ubuntu >> "%LOG%" 2>&1

echo ---- EFI partition now: >> "%LOG%"
dir /b Z:\EFI >> "%LOG%" 2>&1
dir /b Z:\EFI\BOOT >> "%LOG%" 2>&1
mountvol Z: /D >> "%LOG%" 2>&1

echo ---- 5. Removing the Ubuntu boot entry >> "%LOG%"
bcdedit /delete %UBUNTU_ID% >> "%LOG%" 2>&1

echo ---- 6. Adding the OpenCore boot entry >> "%LOG%"
bcdedit /enum firmware | find /i "OpenCore" >nul
if not errorlevel 1 (
  echo OpenCore entry already exists, skipping creation. >> "%LOG%"
  goto done
)
set "OCID="
for /f "tokens=2 delims={}" %%g in ('bcdedit /copy {bootmgr} /d "OpenCore"') do set "OCID={%%g}"
if not defined OCID (
  echo ERROR: could not create the OpenCore entry. >> "%LOG%"
  goto fail
)
echo New entry: %OCID% >> "%LOG%"
bcdedit /set %OCID% path \EFI\OC\OpenCore.efi >> "%LOG%" 2>&1
bcdedit /set {fwbootmgr} displayorder %OCID% /addfirst >> "%LOG%" 2>&1

:done
echo ---- Boot entries now: >> "%LOG%"
bcdedit /enum firmware >> "%LOG%" 2>&1
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
