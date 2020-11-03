@echo off >NUL
@SETLOCAL enableextensions enabledelayedexpansion
pushd %~dp0
:check_Permissions
    net session >nul 2>&1
    if %errorLevel% == 0 (
		goto Sanity
    ) else (
        echo Insufficient Permissions: You must run this program as administrator.
    )

    pause >nul
exit


:Sanity
IF NOT EXIST "%~dp0setupfiles\directory.txt" goto FirstPass
GOTO SanityTwo

:FirstPass
FOR /f "delims=/" %%a IN ('reg query "HKLM\System\CurrentControlSet\Services\freelan service" /v "ImagePath" 2^>NUL' ) DO (
 FOR /f "tokens=1,2,*delims= " %%b IN ("%%a") DO IF "%%b"=="ImagePath" (
    FOR %%m IN ("%%~dpd.") DO ECHO %%~dpm> "%~dp0setupfiles\directory.txt"
 )
)
GOTO FileTest

:FileTest
IF NOT EXIST "%~dp0setupfiles\directory.txt" goto ERROR
GOTO SanityTwo

:ERROR
echo It appears that FreeLAN is not installed.
echo This program is required to play online again.
echo Accept anything that pops up throughout install to avoid errors.
echo Press any button to begin installing the program
pause>NUL

:Install FreeLAN
start /WAIT "" "%~dp0setupfiles\freelan-2.2.0-amd64-install.exe"
goto Sanity


REM :SETUP
REM IF EXIST "%~dp0setupfiles\complete.txt" goto SanityTwo
REM cd setupfiles
REM set /p remotefiles=<directory.txt
REM set "localfiles=freelan.cfg"
REM set "configlocation=%remotefiles%config\"
REM IF NOT EXIST "%localfiles%\complete.txt" (
REM xcopy /y "%localfiles%" "%configlocation%">NUL
REM echo Configuration Completed > complete.txt
REM )
REM cd..

:SanityTwo
tasklist | find /i "freelan.exe" >nul 2>&1
IF ERRORLEVEL 1 (
goto :ASK
) ELSE (
taskkill /F /IM freelan.exe >NUL
goto :ASK
)

:ASK
cls
echo This App must temporarily disable conflicting VPNs 
echo They will be automatically reactivated upon closing Splinter Cell.
echo Known Conflicting VPNs: RAdmin and ZeroTier.
echo If you don't have them, then this process will impact nothing.
set /p choice="Press ENTER to confirm, otherwise close the app..."

:PRECLEAR
cls
echo Locating and Disabling Confilcting VPNs

:Radmin
sc query "RvControlSvc" | find "RUNNING">NUL
if "%ERRORLEVEL%"=="0" (
    net stop RvControlSvc>NUL
	goto :ZeroTier
) else (
	goto :ZeroTier
)

:ZeroTier
sc query "ZeroTierOneService" | find "RUNNING">NUL
if "%ERRORLEVEL%"=="0" (
    net stop ZeroTierOneService>NUL
	goto :KillAdapters
) else (
	goto :KillAdapters
)

:KillAdapters
set "NetConID="
  wmic NIC where Description="Famatech RadminVPN Ethernet Adapter" ^
    list /format:textvaluelist.xsl>"%temp%\wmcnc.txt" 2>&1
  for /F "tokens=1* delims==" %%I in ('type "%temp%\wmcnc.txt"') do (
    if /i "%%I"=="NetConnectionID" set "NetConID=%%~J"
  )
del "%temp%\wmcnc.txt" 2>nul
netsh interface set interface "!NetConID!" Disable>NUL
goto :KillAdapters2

:KillAdapters2
set "NetConID="
  wmic NIC where Description="ZeroTier One Virtual Port" ^
    list /format:textvaluelist.xsl>"%temp%\wmcnc.txt" 2>&1
  for /F "tokens=1* delims==" %%I in ('type "%temp%\wmcnc.txt"') do (
    if /i "%%I"=="NetConnectionID" set "NetConID=%%~J"
  )
del "%temp%\wmcnc.txt" 2>nul
netsh interface set interface "!NetConID!" Disable>NUL
goto :ORIGIN

:ORIGIN
cls
echo Welcome to the Splinter Cell Direct Connection App!
echo Are you the host, or a player of the session...
echo NOTE: Read Note about Hosting...
choice /C 123 /n /M "Host [1], Player [2], CoopFix [3] Info [4]"
if ERRORLEVEL 4 goto NOTE
if ERRORLEVEL 3 goto CoopFix
if ERRORLEVEL 2 goto PLAYER
if ERRORLEVEL 1 goto HOST

:NOTE
cls
echo NOTE ABOUT HOSTING NETWORKS...
echo Most people should be able to host a network for friends.
echo This is due to UPnP bypassing the need to Port Forward.
echo Port Forward 12000 (UDP) if you have issues trying to host.
set /p choice="Press ENTER to dismiss message..."
goto :ORIGIN


:HOST
cls
echo HOW TO HOST
echo Make sure your players know the following information...
echo 1. Your Public IP Address... (Google 'What is my Public IP')
echo 2. Their UNIQUE ID number. (You will give everyone a random UNIQUE number).
echo NOTE: IDs can only be between 2 - 254
echo 3. The Passphrase for your network (You will enter this in shortly.)
set /p choice="Press ENTER to dismiss this notice"
cls
echo Please type your desired passphrase...
SET /P passphrase=
set quoted=^"%passphrase%"^
cd setupfiles
set /p freelandir=<directory.txt
popd
pushd "%freelandir%bin"
start "" "freelan.exe" --security.passphrase %quoted% --tap_adapter.ipv4_address_prefix_length 9.0.0.1/24 --switch.relay_mode_enabled yes --tap_adapter.metric 1 --debug
goto :LOOP


:QUIT
exit

:Player
cls
echo HOW TO JOIN GAMES
echo You will ask the host for the following information.
echo 1. What your UNIQUE ID Number is.
echo 2. What their network passphrase is.
echo 3. What their Public IP Address is.
set /p choice="Press ENTER to dismiss this notice"

:PlayerInfo
cls
echo Please type your Player ID number...
echo NOTE: Ask the host what your ID number is.
SET /p clientid=
echo("%clientid%"|findstr "^[\"][-][1-9][0-9]*[\"]$ ^[\"][1-9][0-9]*[\"]$ ^[\"]0[\"]$">nul&&goto firstcheck||goto INVALIDID

:firstcheck
if %clientid% gtr 1 if %clientid% leq 254 (goto APPROVED)

:INVALIDID
echo You have entered an Invalid ID... Please try again...
pause
goto :PlayerInfo

:APPROVED
echo Please enter the passphrase...
SET /P passphrase=
set quoted=^"%passphrase%"^
echo Please enter the host's Public IP Address...
SET /p hostip=

:ClientConnection
cd setupfiles
set /p freelandir=<directory.txt
popd
pushd "%freelandir%bin"
start "" "freelan.exe" --security.passphrase %quoted% --fscp.contact %hostip%:12000 --tap_adapter.ipv4_address_prefix_length 9.0.0.%clientid%/24 --tap_adapter.metric 1 --debug
goto LOOP

:LOOP
cls
echo Waiting for Splinter Cell To Launch...
tasklist | find /i "SCCT_VERSUS.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOPTWO
) ELSE (
  GOTO LOOPTHREE
)

:LOOPTWO
cls
echo Waiting for Splinter Cell To Launch...
tasklist | find /i "splintercell3.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOPDA
) ELSE (
  GOTO LOOPFOUR
)

:LOOPDA
cls
echo Waiting for Splinter Cell To Launch...
tasklist | find /i "SCDA_online.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOP
) ELSE (
  GOTO LOOPDAG
)


:LOOPTHREE
cls
echo Monitoring Game...
tasklist | find /i "SCCT_VERSUS.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  GOTO :RadminReboot
) ELSE (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOPTHREE
)

:LOOPFOUR
cls
echo Monitoring Game...
tasklist | find /i "splintercell3.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  GOTO :RadminReboot
) ELSE (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOPFOUR
)

:LOOPDAG
cls
echo Monitoring Game...
tasklist | find /i "SCDA_online.exe" >nul 2>&1
IF ERRORLEVEL 1 (
  GOTO :RadminReboot
) ELSE (
  Timeout /T 1 /Nobreak >NUL
  GOTO LOOPDAG
)

:RadminReboot
cls
echo Rebooting Services, Adapters, and closing...
sc query "RvControlSvc" | find "RUNNING">NUL
if "%ERRORLEVEL%"=="0" (
    goto :ZeroTierReboot
) else (
    net start RvControlSvc>NUL
	goto :ZeroTierReboot
)

:ZeroTierReboot
sc query "ZeroTierOneService" | find "RUNNING">NUL
if "%ERRORLEVEL%"=="0" (
    goto :RestoreAdapters
) else (
    net start ZeroTierOneService>NUL
	goto :RestoreAdapters
)

:RestoreAdapters
set "NetConID="
  wmic NIC where Description="Famatech RadminVPN Ethernet Adapter" ^
    list /format:textvaluelist.xsl>"%temp%\wmcnc.txt" 2>&1
  for /F "tokens=1* delims==" %%I in ('type "%temp%\wmcnc.txt"') do (
    if /i "%%I"=="NetConnectionID" set "NetConID=%%~J"
  )
del "%temp%\wmcnc.txt" 2>nul
netsh interface set interface "!NetConID!" Enable>NUL
goto :RestoreAdapters2

:RestoreAdapters2
set "NetConID="
  wmic NIC where Description="ZeroTier One Virtual Port" ^
    list /format:textvaluelist.xsl>"%temp%\wmcnc.txt" 2>&1
  for /F "tokens=1* delims==" %%I in ('type "%temp%\wmcnc.txt"') do (
    if /i "%%I"=="NetConnectionID" set "NetConID=%%~J"
  )
del "%temp%\wmcnc.txt" 2>nul
netsh interface set interface "!NetConID!" Enable>NUL
goto :QUIT

:QUIT
tasklist | find /i "freelan.exe" >nul 2>&1
IF ERRORLEVEL 1 (
exit
) ELSE (
taskkill /F /IM freelan.exe >NUL
exit
)

:CoopFix
cls
echo FIX COMMON COOP ISSUES
echo This utility will help fix common coop issues.
echo The bugs fixed are: Thermal Bug, Instant Disconnect, Hack Disconnect
echo Press any key to proceed...

Set "SExe="
Set "SPth="
For /F "Tokens=1,2*" %%A In ('Reg Query HKCU\SOFTWARE\Valve\Steam') Do (
    If "%%A" Equ "SteamExe" Set "SExe=%%C"
    If "%%A" Equ "SteamPath" Set "SPth=%%C")
If Not Defined SExe Exit/B
Rem Your commands go under here for example
Echo=The full path to the Steam executable is "%SExe%"
If Defined SPth Echo=The Steam folder path is "%SPth%"
set "CPth=%SPth%\steamapps\common\Splintercell Chaos Theory\System"
set "PDPth=%~dp0setupfiles\ProgramData"
set "SDPth=%~dp0setupfiles\System"
set "OPDPth=C:\ProgramData\Ubisoft\Tom Clancy's Splinter Cell Chaos Theory"
if not exist "%CPth%" goto :MissingCOOP
if not exist "%PDPth%" goto :MissingFiles
if not exist "%SDPth%" goto :MissingFiles
REM Echo Coop is located in "%CPth%"
REM Echo Coop ProgramData Fix is in "%PDPth%"
REM Echo Coop SystemData Fix is in "%SDPth%"
set /p choice="Press ENTER to copy files..."
xcopy /s /y "%SDPth%" "%CPth%">NUL
xcopy /s /y "%PDPth%" "%OPDPth%">NUL
Echo Default Profile Cleaned and Thermal Fix Applied...
Echo NOTE: The Thermal Fix is experimental. It may not have worked.
set /p choice="Press ENTER to proceed..."
goto :Ask2

:Ask2
cls
echo Would you like to clean your personal profile?
echo If you choose no, only profile DEFAULT will have been cleaned...
echo The profile cleaning fixes the known disconnection bugs.
choice /C 12 /n /M "Yes [1], No[2]"
if ERRORLEVEL 2 goto :ORIGIN
if ERRORLEVEL 1 goto :CustomClean


:CustomClean
cls
set /p "custom=Type Profile Name Here: "
set "customdir=C:\ProgramData\Ubisoft\Tom Clancy's Splinter Cell Chaos Theory\Profiles\%custom%"
if not exist "%customdir%" goto :TryAgain
set "sourcedefault=%PDPth%\Profiles\DEFAULT\DEFAULT.ini"
set "customfile=%customdir%\%custom%.ini"
xcopy /y "%sourcedefault%" "%customfile%">nul
echo Profile "%custom%" cleaned...
set /p choice="Press any key to return to menu..."
goto :ORIGIN

:TryAgain
cls
echo Profile not found... Try Again?
echo If you choose no, only profile DEFAULT will have been cleaned...
echo The profile cleaning fixes the known disconnection bugs.
choice /C 12 /n /M "Yes [1], No[2]"
if ERRORLEVEL 2 goto :ORIGIN
if ERRORLEVEL 1 goto :CustomClean

:MissingCOOP
cls
echo It appears that COOP is missing...
echo This may be due to use of a non-steam copy...
echo This launcher does cannot clean non-steam copies currently.
echo If you do have a steam copy, but get this error, contact Ndo360
set /p choice="Press ENTER to dismiss error and return to menu"
goto :ORIGIN

:MissingFiles
cls
echo You shouldn't be here...
echo This means your launcher is missing files...
echo Verify that 'SetupFiles' folder exists...
echo If it does, and you got this error, contact Ndo360
set /p choice="Press ENTER to dismiss error and return to menu"
goto :ORIGIN

