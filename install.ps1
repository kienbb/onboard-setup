#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Onboarding Script - Automated development environment setup.

.DESCRIPTION
    Installs all necessary software and tools for development onboarding.
    Supports automatic resume after reboot and crash recovery via state machine.

.NOTES
    File Name      : install.ps1
    Author         : Auto-generated for kiennt
    Prerequisite   : Windows 11, PowerShell 5.1+
    Run            : Right-click -> "Run with PowerShell" or:
                     powershell -ExecutionPolicy Bypass -File install.ps1
#>

#region Configuration
$Script:Config = @{
    StateFile    = "$env:TEMP\onboarding-state.json"
    LogFile      = "$env:TEMP\onboarding.log"
    TempDir      = "$env:TEMP\onboarding"
    ScriptPath   = $MyInvocation.MyCommand.Path
    
    # OpenCode Desktop
    OpenCodeDesktopUrl = "https://opencode.ai/download/stable/windows-x64-nsis"
    
    # Rust
    RustupUrl    = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    
    # IIS Hosting Bundles
    HostingBundles = @(
        @{ Version = "8.0"; Url = "https://aka.ms/dotnet/8.0/dotnet-hosting-win-x64.exe" }
        @{ Version = "9.0"; Url = "https://aka.ms/dotnet/9.0/dotnet-hosting-win-x64.exe" }
    )
}
#endregion

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line -ForegroundColor $(switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "White" }
    })
    Add-Content -Path $Script:Config.LogFile -Value $line -ErrorAction SilentlyContinue
}

function Initialize-State {
    if (Test-Path $Script:Config.StateFile) {
        try {
            $Script:State = Get-Content $Script:Config.StateFile -Raw | ConvertFrom-Json
            Write-Log "Resuming from Phase $($Script:State.Phase)" "INFO"
            return
        } catch {
            Write-Log "Failed to read state file, starting fresh" "WARN"
        }
    }
    $Script:State = @{
        Phase            = 0
        CompletedPackages = @()
        RestartPending   = $false
        StartTime        = (Get-Date).ToString("o")
    }
    Save-State
}

function Save-State {
    try {
        $Script:State | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:Config.StateFile -Force
    } catch {
        Write-Log "Failed to save state: $_" "ERROR"
    }
}

function Register-AutoResume {
    # Primary: RunOnce
    try {
        $value = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($Script:Config.ScriptPath)`""
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "OnboardingResume" -Value $value -Force
        Write-Log "Registered RunOnce for auto-resume" "INFO"
    } catch {
        Write-Log "Failed to register RunOnce: $_" "WARN"
    }
    
    # Backup: Startup shortcut
    try {
        $startupPath = [Environment]::GetFolderPath("CommonStartup")
        $shortcutPath = Join-Path $startupPath "OnboardingResume.lnk"
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($Script:Config.ScriptPath)`""
        $shortcut.WorkingDirectory = Split-Path $Script:Config.ScriptPath
        $shortcut.Save()
        Write-Log "Registered Startup shortcut for auto-resume" "INFO"
    } catch {
        Write-Log "Failed to create Startup shortcut: $_" "WARN"
    }
}

function Remove-AutoResume {
    try {
        Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "OnboardingResume" -Force -ErrorAction SilentlyContinue
    } catch {}
    try {
        $startupPath = [Environment]::GetFolderPath("CommonStartup")
        $shortcutPath = Join-Path $startupPath "OnboardingResume.lnk"
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
    } catch {}
    Write-Log "Cleaned up auto-resume mechanisms" "INFO"
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
    # Refresh PATH from registry for current session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
}

function Get-NpmPath {
    # Try to find npm.cmd in common locations
    $candidates = @(
        "C:\Program Files\nodejs\npm.cmd",
        "C:\Program Files (x86)\nodejs\npm.cmd",
        "$env:ProgramFiles\nodejs\npm.cmd",
        "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Get-VSCodePath {
    # Try to find code.cmd in common locations
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Test-WingetPackageInstalled {
    param([string]$PackageId)
    try {
        $result = & winget list --id $PackageId --exact 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$FriendlyName = $PackageId,
        [string[]]$OverrideArgs = @(),
        [int]$Index = 0,
        [int]$Total = 0
    )
    
    $prefix = if ($Index -gt 0 -and $Total -gt 0) { "[$Index/$Total] " } else { "" }
    
    if ($Script:State.CompletedPackages -contains $PackageId) {
        Write-Log "${prefix}Skipping $FriendlyName (already completed)" "INFO"
        return $true
    }
    
    if (Test-WingetPackageInstalled $PackageId) {
        Write-Log "${prefix}$FriendlyName is already installed" "SUCCESS"
        $Script:State.CompletedPackages += $PackageId
        Save-State
        return $true
    }
    
    Write-Log "${prefix}>>> Installing $FriendlyName..." "INFO"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $timeoutSeconds = 900  # 15 minutes max per package
    
    try {
        $wingetArgs = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
        if ($OverrideArgs.Count -gt 0) {
            $overrideString = $OverrideArgs -join " "
            $wingetArgs += @("--override", $overrideString)
        }
        
        # Use Start-Process without -Wait to support timeout
        $process = Start-Process winget -ArgumentList $wingetArgs -PassThru -NoNewWindow
        Write-Log "${prefix}Started winget (PID: $($process.Id)) for $FriendlyName" "INFO"
        
        # Wait with timeout
        $completed = $process.WaitForExit($timeoutSeconds * 1000)
        $stopwatch.Stop()
        
        if (-not $completed) {
            Write-Log "${prefix}!!! $FriendlyName install timed out after ${timeoutSeconds}s. Killing process..." "WARN"
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                # Also try to kill any child installer processes spawned by winget
                Get-CimInstance Win32_Process -Filter "ParentProcessId = $($process.Id)" | ForEach-Object {
                    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                }
            } catch {}
            Write-Log "${prefix}!!! $FriendlyName skipped due to timeout. You may need to install it manually." "WARN"
            return $false
        }
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) { # Already installed code
            Write-Log "${prefix}<<< $FriendlyName installed successfully (${stopwatch.Elapsed.TotalSeconds:F1}s)" "SUCCESS"
            $Script:State.CompletedPackages += $PackageId
            Save-State
            return $true
        } else {
            Write-Log "${prefix}<<< $FriendlyName install exited with code $($process.ExitCode) (${stopwatch.Elapsed.TotalSeconds:F1}s)" "WARN"
            return $false
        }
    } catch {
        $stopwatch.Stop()
        Write-Log "${prefix}<<< Failed to install ${FriendlyName}: $_ (${stopwatch.Elapsed.TotalSeconds:F1}s)" "ERROR"
        return $false
    }
}

function Install-WingetPackageInteractive {
    param(
        [string]$PackageId,
        [string]$FriendlyName = $PackageId,
        [string[]]$OverrideArgs = @()
    )
    
    if ($Script:State.CompletedPackages -contains $PackageId) {
        Write-Log "Skipping $FriendlyName (already completed)" "INFO"
        return $true
    }
    
    if (Test-WingetPackageInstalled $PackageId) {
        Write-Log "$FriendlyName is already installed" "SUCCESS"
        $Script:State.CompletedPackages += $PackageId
        Save-State
        return $true
    }
    
    Write-Log "Installing $FriendlyName (interactive/visible)..." "INFO"
    try {
        $wingetArgs = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
        if ($OverrideArgs.Count -gt 0) {
            $overrideString = $OverrideArgs -join " "
            $wingetArgs += @("--override", $overrideString)
        }
        
        # Run without -NoNewWindow to allow VS Installer UI
        $process = Start-Process winget -ArgumentList $wingetArgs -Wait -PassThru
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
            Write-Log "$FriendlyName installed successfully" "SUCCESS"
            $Script:State.CompletedPackages += $PackageId
            Save-State
            return $true
        } else {
            Write-Log "$FriendlyName install exited with code $($process.ExitCode)" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to install ${FriendlyName}: $_" "ERROR"
        return $false
    }
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutFile
    )
    try {
        Write-Log "Downloading from $Url..." "INFO"
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Download failed: $_" "ERROR"
        return $false
    }
}

#endregion

#region Bootstrap

function Start-Phase0 {
    Write-Log "========== PHASE 0: Bootstrap ==========" "INFO"
    
    # Ensure temp dir
    if (-not (Test-Path $Script:Config.TempDir)) {
        New-Item -ItemType Directory -Path $Script:Config.TempDir -Force | Out-Null
    }
    
    # Check Chocolatey
    if (-not (Test-CommandExists choco)) {
        Write-Log "Installing Chocolatey..." "INFO"
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            refreshenv
            Write-Log "Chocolatey installed" "SUCCESS"
        } catch {
            Write-Log "Chocolatey install failed (non-critical): $_" "WARN"
        }
    } else {
        Write-Log "Chocolatey is already installed" "INFO"
    }
    
    # Check Winget
    if (-not (Test-CommandExists winget)) {
        Write-Log "Winget not found! Attempting to install via Chocolatey..." "WARN"
        try {
            choco install winget-cli -y --no-progress
            refreshenv
        } catch {
            Write-Log "Winget install failed. Please install manually." "ERROR"
            throw "Winget is required but could not be installed."
        }
    }
    
    # Update Winget sources
    try {
        & winget source update | Out-Null
        Write-Log "Winget sources updated" "INFO"
    } catch {
        Write-Log "Winget source update warning: $_" "WARN"
    }
    
    Write-Log "Bootstrap completed" "SUCCESS"
    $Script:State.Phase = 1
    Save-State
}

#endregion

#region Phase 1: Windows Features, WSL2, Settings, Git Config

function Start-Phase1 {
    Write-Log "========== PHASE 1: Windows Features, WSL2, Settings, Git Config ==========" "INFO"
    
    # Enable Windows Features
    $features = @(
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform"
    )
    foreach ($feature in $features) {
        Write-Log "Enabling feature: $feature" "INFO"
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction Stop | Out-Null
            Write-Log "Feature $feature enabled" "SUCCESS"
        } catch {
            Write-Log "Feature $feature may already be enabled or failed: $_" "WARN"
        }
    }
    
    # Enable IIS Features
    $iisFeatures = @(
        "IIS-WebServerRole",
        "IIS-WebServer",
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpRedirect",
        "IIS-ApplicationDevelopment",
        "IIS-HealthAndDiagnostics",
        "IIS-HttpLogging",
        "IIS-Security",
        "IIS-RequestFiltering",
        "IIS-Performance",
        "IIS-StaticContent",
        "IIS-DefaultDocument",
        "IIS-DirectoryBrowsing",
        "IIS-WebDAV",
        "IIS-WebSockets",
        "IIS-ApplicationInit",
        "IIS-NetFxExtensibility45",
        "IIS-ASPNET45",
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter",
        "IIS-HttpCompressionStatic",
        "IIS-HttpCompressionDynamic",
        "IIS-ManagementConsole",
        "IIS-ManagementService"
    )
    foreach ($feature in $iisFeatures) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Some features may already be enabled
        }
    }
    Write-Log "IIS features enabled" "SUCCESS"
    
    # Install WSL2 + Ubuntu
    Write-Log "Installing WSL2 with Ubuntu..." "INFO"
    try {
        wsl --install --distribution Ubuntu --no-launch 2>$null
        Write-Log "WSL2 + Ubuntu installation initiated" "SUCCESS"
    } catch {
        Write-Log "WSL2 install command warning: $_" "WARN"
    }
    
    # Dark Mode
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
        Write-Log "Dark mode enabled" "SUCCESS"
    } catch {
        Write-Log "Failed to enable dark mode: $_" "WARN"
    }
    
    # Show File Extensions
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $regPath -Name "HideFileExt" -Value 0 -Type DWord -Force
        Write-Log "File extensions shown" "SUCCESS"
    } catch {
        Write-Log "Failed to show file extensions: $_" "WARN"
    }
    
    # Restart Explorer to apply settings
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } catch {}
    
    # Git Config
    Write-Log "Configuring Git..." "INFO"
    try {
        & git config --global user.name "kiennt"
        & git config --global user.email "kiennt@pixon.games"
        Write-Log "Git configured: kiennt / kiennt@pixon.games" "SUCCESS"
    } catch {
        Write-Log "Git config warning (Git may not be installed yet): $_" "WARN"
    }
    
    Write-Log "Phase 1 completed. Restart required to continue." "SUCCESS"
    $Script:State.Phase = 2
    $Script:State.RestartPending = $true
    Save-State
    
    Register-AutoResume
    
    Write-Log "Restarting computer in 30 seconds... Save your work!" "WARN"
    Start-Sleep -Seconds 30
    Restart-Computer -Force
}

#endregion

#region Phase 2: Post-Reboot Check

function Start-Phase2 {
    Write-Log "========== PHASE 2: Post-Reboot Verification ==========" "INFO"
    
    # Wait a bit for WSL to settle
    Start-Sleep -Seconds 10
    
    # Check WSL status
    try {
        $wslStatus = & wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 is ready" "SUCCESS"
        } else {
            Write-Log "WSL2 may need additional setup. Continuing anyway..." "WARN"
        }
    } catch {
        Write-Log "WSL2 status check failed: $_" "WARN"
    }
    
    # Check Ubuntu
    try {
        $distros = & wsl --list --quiet 2>$null
        if ($distros -match "Ubuntu") {
            Write-Log "Ubuntu distro detected" "SUCCESS"
        } else {
            Write-Log "Ubuntu not yet registered. You may need to complete first-launch setup manually." "WARN"
        }
    } catch {
        Write-Log "Ubuntu check failed: $_" "WARN"
    }
    
    $Script:State.RestartPending = $false
    $Script:State.Phase = 3
    Save-State
}

#endregion

#region Phase 3: Silent Packages via Winget

function Start-Phase3 {
    Write-Log "========== PHASE 3: Silent Package Installation ==========" "INFO"
    
    $packages = @(
        @{ Id = "7zip.7zip"; Name = "7-Zip" },
        @{ Id = "Notepad++.Notepad++"; Name = "Notepad++" },
        @{ Id = "Google.Chrome"; Name = "Google Chrome" },
        @{ Id = "Discord.Discord"; Name = "Discord" },
        @{ Id = "Git.Git"; Name = "Git" },
        @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal" },
        @{ Id = "Microsoft.PowerToys"; Name = "PowerToys" },
        @{ Id = "Telegram.TelegramDesktop"; Name = "Telegram Desktop" },
        @{ Id = "OpenJS.NodeJS.LTS"; Name = "Node.js LTS" },
        @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" },
        @{ Id = "Postman.Postman"; Name = "Postman" },
        @{ Id = "DanPristupov.Fork"; Name = "Fork Git UI" },
        @{ Id = "Unity.UnityHub"; Name = "Unity Hub" }
    )
    
    $totalPackages = $packages.Count + 3 # +3 for .NET SDK 8, 9, 10
    $currentIndex = 0
    
    foreach ($pkg in $packages) {
        $currentIndex++
        Install-WingetPackage -PackageId $pkg.Id -FriendlyName $pkg.Name -Index $currentIndex -Total $totalPackages | Out-Null
    }
    
    # .NET SDKs
    $currentIndex++
    Install-WingetPackage -PackageId "Microsoft.DotNet.SDK.8" -FriendlyName ".NET SDK 8" -Index $currentIndex -Total $totalPackages | Out-Null
    $currentIndex++
    Install-WingetPackage -PackageId "Microsoft.DotNet.SDK.9" -FriendlyName ".NET SDK 9" -Index $currentIndex -Total $totalPackages | Out-Null
    
    # .NET 10 - attempt, skip if not available
    $currentIndex++
    Write-Log "[$currentIndex/$totalPackages] Attempting to install .NET SDK 10..." "INFO"
    try {
        $available = & winget search --id "Microsoft.DotNet.SDK.10" --exact 2>$null
        if ($LASTEXITCODE -eq 0) {
            Install-WingetPackage -PackageId "Microsoft.DotNet.SDK.10" -FriendlyName ".NET SDK 10" -Index $currentIndex -Total $totalPackages | Out-Null
        } else {
            Write-Log "[$currentIndex/$totalPackages] .NET SDK 10 not available yet, skipping" "WARN"
        }
    } catch {
        Write-Log "[$currentIndex/$totalPackages] .NET SDK 10 search/install failed, skipping: $_" "WARN"
    }
    
    Write-Log "Phase 3 completed ($totalPackages packages processed)" "SUCCESS"
    $Script:State.Phase = 4
    Save-State
}

#endregion

#region Phase 4: Python via pyenv-win

function Start-Phase4 {
    Write-Log "========== PHASE 4: Python (pyenv-win) ==========" "INFO"
    
    # Check if pyenv is installed
    $pyenvRoot = "$env:USERPROFILE\.pyenv"
    $pyenvExists = Test-Path (Join-Path $pyenvRoot "pyenv-win\bin\pyenv.bat")
    
    if (-not $pyenvExists) {
        Write-Log "Installing pyenv-win..." "INFO"
        try {
            $installUrl = "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1"
            $installScript = "$env:TEMP\install-pyenv-win.ps1"
            
            Invoke-WebRequest -UseBasicParsing -Uri $installUrl -OutFile $installScript -ErrorAction Stop
            & $installScript
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            Write-Log "pyenv-win installed" "SUCCESS"
        } catch {
            Write-Log "pyenv-win installation failed: $_" "ERROR"
            Write-Log "You may need to install Python manually" "WARN"
            return
        }
    } else {
        Write-Log "pyenv-win is already installed" "INFO"
    }
    
    # Add pyenv to current session PATH if needed
    $pyenvPath = "$env:USERPROFILE\.pyenv\pyenv-win\bin"
    $pyenvShims = "$env:USERPROFILE\.pyenv\pyenv-win\shims"
    if ($env:PATH -notlike "*$pyenvPath*") {
        $env:PATH = "$pyenvPath;$pyenvShims;$env:PATH"
    }
    
    $pyenvCmd = "$env:USERPROFILE\.pyenv\pyenv-win\bin\pyenv.bat"
    if (-not (Test-Path $pyenvCmd)) {
        Write-Log "pyenv.bat not found after installation. Python setup may require a manual restart." "ERROR"
        return
    }
    
    # Install Python versions
    $versions = @("3.10", "3.11", "3.12", "3.13")
    foreach ($ver in $versions) {
        Write-Log "Installing Python $ver via pyenv..." "INFO"
        try {
            # pyenv install may take a while
            $proc = Start-Process -FilePath $pyenvCmd -ArgumentList "install", $ver -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-Log "Python $ver installed" "SUCCESS"
            } else {
                Write-Log "Python $ver install exited with code $($proc.ExitCode). It may already be installed." "WARN"
            }
        } catch {
            Write-Log "Python $ver install error: $_" "WARN"
        }
    }
    
    # Set global to 3.13
    try {
        & $pyenvCmd global 3.13
        & $pyenvCmd rehash
        Write-Log "Python 3.13 set as global default" "SUCCESS"
    } catch {
        Write-Log "Failed to set Python 3.13 as global: $_" "WARN"
    }
    
    Write-Log "Phase 4 completed" "SUCCESS"
    $Script:State.Phase = 5
    Save-State
}

#endregion

#region Phase 5: Rust

function Start-Phase5 {
    Write-Log "========== PHASE 5: Rust ==========" "INFO"
    
    if (Test-CommandExists rustc) {
        $ver = & rustc --version 2>$null
        Write-Log "Rust already installed: $ver" "SUCCESS"
        $Script:State.Phase = 6
        Save-State
        return
    }
    
    $installer = "$env:TEMP\rustup-init.exe"
    if (Invoke-Download -Url $Script:Config.RustupUrl -OutFile $installer) {
        Write-Log "Running rustup-init..." "INFO"
        try {
            $proc = Start-Process -FilePath $installer -ArgumentList "-y", "--quiet" -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-Log "Rust installed successfully" "SUCCESS"
                # Update PATH for current session
                $cargoPath = "$env:USERPROFILE\.cargo\bin"
                if ($env:PATH -notlike "*$cargoPath*") {
                    $env:PATH = "$cargoPath;$env:PATH"
                }
            } else {
                Write-Log "rustup-init exited with code $($proc.ExitCode)" "WARN"
            }
        } catch {
            Write-Log "Rust installation failed: $_" "ERROR"
        }
    }
    
    $Script:State.Phase = 6
    Save-State
}

#endregion

#region Phase 6: IIS Hosting Bundle

function Start-Phase6 {
    Write-Log "========== PHASE 6: IIS Hosting Bundle ==========" "INFO"
    
    foreach ($bundle in $Script:Config.HostingBundles) {
        Write-Log "Installing .NET Hosting Bundle $($bundle.Version)..." "INFO"
        $installer = "$env:TEMP\dotnet-hosting-$($bundle.Version)-win-x64.exe"
        
        if (Invoke-Download -Url $bundle.Url -OutFile $installer) {
            try {
                $proc = Start-Process -FilePath $installer -ArgumentList "/quiet", "/install", "/norestart" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) { # 3010 = success, reboot required
                    Write-Log "Hosting Bundle $($bundle.Version) installed" "SUCCESS"
                } else {
                    Write-Log "Hosting Bundle $($bundle.Version) exited with code $($proc.ExitCode)" "WARN"
                }
            } catch {
                Write-Log "Hosting Bundle $($bundle.Version) install failed: $_" "ERROR"
            }
        } else {
            Write-Log "Failed to download Hosting Bundle $($bundle.Version). You may need to install manually." "WARN"
        }
    }
    
    # Reset IIS
    try {
        & iisreset /restart | Out-Null
        Write-Log "IIS restarted" "SUCCESS"
    } catch {
        Write-Log "IIS reset warning: $_" "WARN"
    }
    
    $Script:State.Phase = 7
    Save-State
}

#endregion

#region Phase 7: Visual Studio Community 2022

function Start-Phase7 {
    Write-Log "========== PHASE 7: Visual Studio Community 2022 ==========" "INFO"
    
    $packageId = "Microsoft.VisualStudio.2022.Community"
    
    if ($Script:State.CompletedPackages -contains $packageId) {
        Write-Log "Visual Studio Community already completed, skipping" "INFO"
        $Script:State.Phase = 8
        Save-State
        return
    }
    
    if (Test-WingetPackageInstalled $packageId) {
        Write-Log "Visual Studio Community is already installed" "SUCCESS"
        $Script:State.CompletedPackages += $packageId
        Save-State
        $Script:State.Phase = 8
        Save-State
        return
    }
    
    Write-Log "Installing Visual Studio Community 2022 with workloads..." "INFO"
    Write-Log "NOTE: VS Installer progress window will appear. Do not interact with it." "WARN"
    
    $override = @(
        "--add", "Microsoft.VisualStudio.Workload.NetWeb",
        "--add", "Microsoft.VisualStudio.Workload.NativeDesktop",
        "--add", "Microsoft.VisualStudio.Workload.Unity",
        "--includeRecommended",
        "--passive",
        "--norestart"
    )
    
    $result = Install-WingetPackageInteractive -PackageId $packageId -FriendlyName "Visual Studio Community 2022" -OverrideArgs $override
    
    if (-not $result) {
        Write-Log "Visual Studio install may have failed or been cancelled. You can install manually later." "WARN"
    }
    
    $Script:State.Phase = 8
    Save-State
}

#endregion

#region Phase 8: OpenCode Desktop

function Start-Phase8 {
    Write-Log "========== PHASE 8: OpenCode Desktop ==========" "INFO"
    
    $packageId = "OpenCodeDesktop" # Fake ID for tracking
    
    if ($Script:State.CompletedPackages -contains $packageId) {
        Write-Log "OpenCode Desktop already completed, skipping" "INFO"
        $Script:State.Phase = 9
        Save-State
        return
    }
    
    # Check if already installed (by common paths)
    $installPaths = @(
        "$env:LOCALAPPDATA\Programs\OpenCode",
        "$env:ProgramFiles\OpenCode",
        "$env:ProgramFiles(x86)\OpenCode"
    )
    $alreadyInstalled = $false
    foreach ($path in $installPaths) {
        if (Test-Path $path) { $alreadyInstalled = $true; break }
    }
    
    if ($alreadyInstalled) {
        Write-Log "OpenCode Desktop is already installed" "SUCCESS"
        $Script:State.CompletedPackages += $packageId
        Save-State
        $Script:State.Phase = 9
        Save-State
        return
    }
    
    $installer = "$env:TEMP\opencode-desktop-setup.exe"
    if (Invoke-Download -Url $Script:Config.OpenCodeDesktopUrl -OutFile $installer) {
        Write-Log "Installing OpenCode Desktop (silent NSIS)..." "INFO"
        try {
            $proc = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-Log "OpenCode Desktop installed" "SUCCESS"
                $Script:State.CompletedPackages += $packageId
                Save-State
            } else {
                Write-Log "OpenCode Desktop installer exited with code $($proc.ExitCode)" "WARN"
            }
        } catch {
            Write-Log "OpenCode Desktop install failed: $_" "ERROR"
        }
    } else {
        Write-Log "Failed to download OpenCode Desktop installer" "ERROR"
    }
    
    $Script:State.Phase = 9
    Save-State
}

#endregion

#region Phase 9: CLI Tools (Claude Code + OpenCode CLI)

function Start-Phase9 {
    Write-Log "========== PHASE 9: CLI Tools (Claude Code + OpenCode CLI) ==========" "INFO"
    
    Update-SessionPath
    
    $npmCmd = Get-NpmPath
    if (-not $npmCmd -and -not (Test-CommandExists npm)) {
        Write-Log "npm not found. Node.js may not be installed yet. Skipping CLI tools." "WARN"
        $Script:State.Phase = 10
        Save-State
        return
    }
    if (-not $npmCmd) { $npmCmd = "npm" }
    
    # Claude Code Terminal
    Write-Log "Installing Claude Code CLI..." "INFO"
    try {
        $proc = Start-Process $npmCmd -ArgumentList "install", "-g", "@anthropic-ai/claude-code" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            Write-Log "Claude Code CLI installed" "SUCCESS"
        } else {
            Write-Log "Claude Code CLI install exited with code $($proc.ExitCode)" "WARN"
        }
    } catch {
        Write-Log "Claude Code CLI install failed: $_" "ERROR"
    }
    
    # OpenCode CLI
    Write-Log "Installing OpenCode CLI (opencode-ai)..." "INFO"
    try {
        $proc = Start-Process $npmCmd -ArgumentList "install", "-g", "opencode-ai" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            Write-Log "OpenCode CLI installed" "SUCCESS"
        } else {
            Write-Log "OpenCode CLI install exited with code $($proc.ExitCode). Package may not exist on npm." "WARN"
        }
    } catch {
        Write-Log "OpenCode CLI install failed: $_" "ERROR"
    }
    
    $Script:State.Phase = 10
    Save-State
}

#endregion

#region Phase 10: VS Code Extensions

function Start-Phase10 {
    Write-Log "========== PHASE 10: VS Code Extensions ==========" "INFO"
    
    Update-SessionPath
    
    $codeCmd = Get-VSCodePath
    if (-not $codeCmd -and -not (Test-CommandExists code)) {
        Write-Log "VS Code CLI (code) not found in PATH. Skipping extension install." "WARN"
        Write-Log "Please install extensions manually: anthropic.claude-code" "INFO"
        $Script:State.Phase = 11
        Save-State
        return
    }
    if (-not $codeCmd) { $codeCmd = "code" }
    
    $extensions = @(
        @{ Id = "anthropic.claude-code"; Name = "Claude Code" }
    )
    
    foreach ($ext in $extensions) {
        Write-Log "Installing VS Code extension: $($ext.Name)..." "INFO"
        try {
            $proc = Start-Process $codeCmd -ArgumentList "--install-extension", $ext.Id, "--force" -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-Log "Extension $($ext.Name) installed" "SUCCESS"
            } else {
                Write-Log "Extension $($ext.Name) install exited with code $($proc.ExitCode)" "WARN"
            }
        } catch {
            Write-Log "Extension $($ext.Name) install failed: $_" "ERROR"
        }
    }
    
    $Script:State.Phase = 11
    Save-State
}

#endregion

#region Phase 11: Cleanup & Report

function Start-Phase11 {
    Write-Log "========== PHASE 11: Cleanup & Final Report ==========" "INFO"
    
    Remove-AutoResume
    
    # Remove state file (keep log for reference)
    try {
        if (Test-Path $Script:Config.StateFile) {
            Remove-Item $Script:Config.StateFile -Force
        }
    } catch {
        Write-Log "Failed to remove state file: $_" "WARN"
    }
    
    # Final report
    Write-Log "========================================" "SUCCESS"
    Write-Log "   ONBOARDING INSTALLATION COMPLETE!    " "SUCCESS"
    Write-Log "========================================" "SUCCESS"
    Write-Log "Log file saved to: $($Script:Config.LogFile)" "INFO"
    Write-Log "" "INFO"
    Write-Log "Manual steps remaining:" "WARN"
    Write-Log "  1. Launch Unity Hub, login, and install Unity 6000.4 + modules (Android, WebGL, iOS)" "WARN"
    Write-Log "  2. Complete WSL2/Ubuntu first-launch setup if prompted" "WARN"
    Write-Log "  3. Restart your computer if any installations requested it" "WARN"
    Write-Log "" "INFO"
    Write-Log "Installed packages: $($Script:State.CompletedPackages -join ', ')" "INFO"
}

#endregion

#region Main Execution

function Start-Onboarding {
    Clear-Host
    Write-Host @"
========================================
   Windows Onboarding Script
   Auto-install dev environment
========================================
"@ -ForegroundColor Cyan
    
    # Ensure admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script not running as Administrator. Relaunching with elevated privileges..." "WARN"
        Start-Sleep -Seconds 2
        $arguments = "-ExecutionPolicy Bypass -File `"$($Script:Config.ScriptPath)`""
        Start-Process powershell -Verb RunAs -ArgumentList $arguments
        exit
    }
    
    Initialize-State
    
    # Execute phases based on state
    switch ($Script:State.Phase) {
        0 { Start-Phase0 }
        1 { Start-Phase1 }
        2 { Start-Phase2 }
        3 { Start-Phase3 }
        4 { Start-Phase4 }
        5 { Start-Phase5 }
        6 { Start-Phase6 }
        7 { Start-Phase7 }
        8 { Start-Phase8 }
        9 { Start-Phase9 }
        10 { Start-Phase10 }
        11 { Start-Phase11 }
        default {
            Write-Log "Unknown phase $($Script:State.Phase). Resetting." "ERROR"
            $Script:State.Phase = 0
            Save-State
            Start-Phase0
        }
    }
    
    # If we just finished a phase and it's not the final one, continue automatically
    while ($Script:State.Phase -lt 11 -and $Script:State.Phase -gt 0) {
        switch ($Script:State.Phase) {
            1 { Start-Phase1 }
            2 { Start-Phase2 }
            3 { Start-Phase3 }
            4 { Start-Phase4 }
            5 { Start-Phase5 }
            6 { Start-Phase6 }
            7 { Start-Phase7 }
            8 { Start-Phase8 }
            9 { Start-Phase9 }
            10 { Start-Phase10 }
            11 { Start-Phase11; break }
        }
    }
}

# Run
Start-Onboarding

#endregion
