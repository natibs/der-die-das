<#
  Der Die Das - one-shot setup / run script for Windows.
  Double-click run.cmd, or:
    powershell -ExecutionPolicy Bypass -File .\setup.ps1          # Android emulator (hot reload: r)
    powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Web     # live preview in Chrome
    powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Apk     # release APK
    powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Tablet  # Pixel Tablet emulator
    powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Phone   # your USB-connected phone
  Installs Flutter and an Android emulator if missing. Logs to setup.log.
#>
param([switch]$Apk, [switch]$Web, [switch]$Tablet, [switch]$Phone)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$log = Join-Path $PSScriptRoot 'setup.log'
"=== setup $(Get-Date -Format s) ===" | Set-Content $log
function Log([string]$m) { Write-Host ">> $m" -ForegroundColor Cyan; ">> $m" | Add-Content $log }
function Run([string]$exe, [string[]]$a, [object[]]$stdin = $null, [switch]$NoThrow) {
    Log "$exe $($a -join ' ')"
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($stdin) { $stdin | & $exe @a 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append | Out-Host }
    else { & $exe @a 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append | Out-Host }
    $code = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($code -ne 0) {
        if ($NoThrow) { Log "WARNING: exit code $code" } else { throw "$exe $($a -join ' ') failed with exit code $code" }
    }
}

function Ensure-Flutter {
    if (Get-Command flutter -ErrorAction SilentlyContinue) { return }
    $flutterDir = Join-Path $env:USERPROFILE 'flutter'
    if (-not (Test-Path (Join-Path $flutterDir 'bin\flutter.bat'))) {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Run git @('clone', 'https://github.com/flutter/flutter.git', '-b', 'stable', '--depth', '1', $flutterDir)
        } else {
            Log 'git not found - downloading the Flutter stable zip (~1 GB)'
            $base = 'https://storage.googleapis.com/flutter_infra_release/releases'
            $rel = Invoke-RestMethod "$base/releases_windows.json"
            $archive = ($rel.releases | Where-Object { $_.hash -eq $rel.current_release.stable } | Select-Object -First 1).archive
            $zip = Join-Path $env:TEMP 'flutter.zip'
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest "$base/$archive" -OutFile $zip
            tar -xf $zip -C $env:USERPROFILE
        }
    }
    $bin = Join-Path $flutterDir 'bin'
    $env:Path = "$bin;$env:Path"
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$bin*") { [Environment]::SetEnvironmentVariable('Path', "$bin;$userPath", 'User') }
}

function Ensure-Avd([string]$sdk, [string]$name, [string]$devProfile) {
    $emulator = Join-Path $sdk 'emulator\emulator.exe'
    if (Test-Path $emulator) {
        $avds = @(& $emulator -list-avds 2>$null | Where-Object { $_ -and $_ -notmatch '^(INFO|WARNING)' })
        if ($avds -contains $name) { Log "Using emulator $name"; return }
    }
    Log "Creating emulator $name ($devProfile) - downloads the Android 15 image the first time (~1.5 GB)"
    $jbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (-not $env:JAVA_HOME -and (Test-Path $jbr)) { $env:JAVA_HOME = $jbr }
    Log "JAVA_HOME: $env:JAVA_HOME"
    $sdkm = Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter sdkmanager.bat -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sdkm) {
        Log 'Downloading Android command-line tools'
        $zip = Join-Path $env:TEMP 'cmdline-tools.zip'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $zip
        $tmp = Join-Path $env:TEMP 'cmdline-tools-x'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        New-Item -ItemType Directory $tmp | Out-Null
        tar -xf $zip -C $tmp
        New-Item -ItemType Directory (Join-Path $sdk 'cmdline-tools') -Force | Out-Null
        Move-Item (Join-Path $tmp 'cmdline-tools') (Join-Path $sdk 'cmdline-tools\latest')
        $sdkm = Get-Item (Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat')
    }
    $sdkmanager = $sdkm.FullName
    $avdmanager = Join-Path $sdkm.DirectoryName 'avdmanager.bat'
    $img = 'system-images;android-35;google_apis;x86_64'
    Run $sdkmanager @('--licenses') -stdin (@('y') * 40) -NoThrow
    # big download - retry on network hiccups (sdkmanager resumes completed packages)
    for ($i = 1; $i -le 4; $i++) {
        try { Run $sdkmanager @('--install', 'platform-tools', 'emulator', 'platforms;android-35', $img); break }
        catch { if ($i -eq 4) { throw }; Log "Download failed (attempt $i), retrying in 10s"; Start-Sleep 10 }
    }
    Run $avdmanager @('create', 'avd', '-n', $name, '-k', $img, '-d', $devProfile, '--force') -stdin @('no')
}

# Serial (emulator-5554...) of the running emulator with this AVD name, or $null.
function Get-AvdSerial([string]$adb, [string]$name) {
    foreach ($line in (& $adb devices)) {
        if ($line -match '^(emulator-\d+)\s+device$') {
            $s = $Matches[1]
            # The system property is reliable; the emulator console ('emu avd name') is the fallback.
            $avdName = "$(& $adb -s $s shell getprop ro.boot.qemu.avd_name 2>$null)".Trim()
            if (-not $avdName) { $avdName = "$((& $adb -s $s emu avd name 2>$null) | Select-Object -First 1)".Trim() }
            if ($avdName -eq $name) { return $s }
        }
    }
    return $null
}

# Makes sure the AVD has the computer keyboard enabled, starts it if needed, waits for boot.
function Start-Avd([string]$sdk, [string]$adb, [string]$name) {
    $cfg = Join-Path $env:USERPROFILE ".android\avd\$name.avd\config.ini"
    if (Test-Path $cfg) {
        $c = [IO.File]::ReadAllText($cfg)
        if ($c -notmatch '(?m)^hw\.keyboard\s*=\s*yes') {
            $c = ($c -replace '(?m)^hw\.keyboard\s*=.*\r?\n?', '').TrimEnd() + "`r`nhw.keyboard=yes`r`n"
            [IO.File]::WriteAllText($cfg, $c)
            Log "Enabled the physical keyboard for $name"
            $running = Get-AvdSerial $adb $name
            if ($running) { Log 'Restarting it to apply'; & $adb -s $running emu kill | Out-Null; Start-Sleep -Seconds 10 }
        }
    }
    $serial = Get-AvdSerial $adb $name
    if (-not $serial) {
        Log "Starting emulator $name"
        Start-Process (Join-Path $sdk 'emulator\emulator.exe') -ArgumentList '-avd', $name
        $t = 0
        while (-not ($serial = Get-AvdSerial $adb $name)) { Start-Sleep 3; $t += 3; if ($t -gt 180) { throw "Emulator $name did not appear" } }
    }
    $t = 0
    while ((& $adb -s $serial shell getprop sys.boot_completed 2>$null) -ne '1') { Start-Sleep 3; $t += 3; if ($t -gt 300) { throw 'Emulator did not boot in 5 min' } }
    return $serial
}

try {
    Ensure-Flutter
    Run flutter @('--version')

    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    Log "Android SDK: $sdk (exists: $(Test-Path $sdk))"
    if (Test-Path $sdk) { Run flutter @('config', '--android-sdk', $sdk) }

    if (-not (Test-Path 'android')) {
        Run flutter @('create', '--org', 'com.natib', '--project-name', 'der_die_das', '--platforms', 'android,web', '.')
    }
    $manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
    $xml = [IO.File]::ReadAllText($manifest)
    if ($xml -notmatch 'android\.permission\.INTERNET') {
        $xml = $xml -replace '(<manifest[^>]*>)', "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    }
    $xml = $xml -replace 'android:label="der_die_das"', 'android:label="Der Die Das"'
    [IO.File]::WriteAllText($manifest, $xml)
    # Project on D: + pub cache on C: breaks Kotlin incremental caches on Windows
    $gp = Join-Path $PSScriptRoot 'android\gradle.properties'
    if (-not (Select-String -Path $gp -Pattern 'kotlin.incremental' -Quiet)) { Add-Content $gp "`nkotlin.incremental=false" }

    Run flutter @('pub', 'get')
    Run flutter @('analyze', '--no-fatal-infos', '--no-fatal-warnings') -NoThrow
    Run flutter @('test') -NoThrow

    if ($Apk) {
        Run flutter @('build', 'apk', '--release')
        Log "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"
    } elseif ($Web) {
        flutter run -d chrome
    } else {
        $adb = Join-Path $sdk 'platform-tools\adb.exe'
        if ($Phone) {
            # first physical device (not an emulator) that's authorized
            $serial = ((& $adb devices) | Where-Object { $_ -match '^(\S+)\s+device$' -and $_ -notmatch '^emulator-' } |
                Select-Object -First 1) -replace '\s+device$', ''
            if (-not $serial) { throw 'No phone found. Connect it by USB, enable USB debugging, and accept the prompt on the phone.' }
        } else {
            $avd, $devProfile = if ($Tablet) { 'DerDieDasTablet', 'pixel_tablet' } else { 'DerDieDas', 'pixel_7' }
            Ensure-Avd $sdk $avd $devProfile
            $serial = Start-Avd $sdk $adb $avd
        }
        Run flutter @('build', 'apk', '--debug')   # compile errors land in setup.log
        Log "Running on $serial - press r to hot reload, q to quit"
        flutter run -d $serial
    }
    Log 'DONE'
} catch {
    "ERROR: $_" | Add-Content $log
    Write-Host "ERROR: $_" -ForegroundColor Red
}
