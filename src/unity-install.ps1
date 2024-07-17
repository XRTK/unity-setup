param(
    [String]$unityVersion,
    [String]$versionFilePath,
    [String]$modulesList,
    [String]$architecture
)
# Unity Editor Installation
$modules = $modulesList.Split(" ")

if ([String]::IsNullOrEmpty($unityVersion)) {
    $projectPath = $env:UNITY_PROJECT_PATH

    if ([String]::IsNullOrEmpty($projectPath)) {
        if ( -not (Test-Path -Path $versionFilePath) ) {
            Write-Error "Failed to find a valid project version file at `"$versionFilePath`""
            exit 1
        }

        $projectPath = (Get-Item $versionFilePath).Directory.Parent.FullName
        $projectPath = $projectPath -replace '\\', '/'
        Write-Host "Unity project path: `"$projectPath`""
        "UNITY_PROJECT_PATH=$projectPath" >> $env:GITHUB_ENV
    }

    $version = Get-Content $versionFilePath
    $pattern = '(?<version>(?:(?<major>\d+)\.)?(?:(?<minor>\d+)\.)?(?:(?<patch>\d+[fab]\d+)\b))|((?:\((?<revision>\w+))\))'
    $vMatches = [regex]::Matches($version, $pattern)
    $unityVersion = $vMatches[1].Groups['version'].Value.Trim()
    $unityVersionChangeSet = $vMatches[2].Groups['revision'].Value.Trim()
}
else {
    $version = $unityVersion
    $unityVersionChangeSet = $version -replace '.*\((.*)\)', '$1'
    $unityVersion = $version -replace '\s*\(.*\)', ''
}

if (-not ([String]::IsNullOrEmpty($unityVersion))) {
    Write-Host ""
    "UNITY_EDITOR_VERSION=$unityVersion" >> $env:GITHUB_ENV
    Write-Host "Unity Editor version set to: $unityVersion"
}
else {
    Write-Error "Failed to determine editor version to install!"
    exit 1
}

if ($IsWindows) {
    $hubPath = "C:/Program Files/Unity Hub/Unity Hub.exe"
    $editorRootPath = "C:/Program Files/Unity/Hub/Editor/"
    $editorFileEx = "/Editor/Unity.exe"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('windows-il2cpp', 'universal-windows-platform', 'android', 'ios')
    }

    #. 'C:/Program Files/Unity Hub/Unity Hub.exe' -- --headless help
    function Invoke-UnityHub {
        $argList = (@('--', '--headless') + $args.Split(" "))
        $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList $argList
        $p.WaitForExit()
    }
}
elseif ($IsMacOS) {
    $hubPath = "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
    $editorRootPath = "/Applications/Unity/Hub/Editor/"
    $editorFileEx = "/Unity.app"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('mac-il2cpp', 'ios', 'android')
    }

    #. "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless help
    function Invoke-UnityHub {
        $argList = (@('--', '--headless') + $args.Split(" "))
        $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList $argList
        $p.WaitForExit()
    }
}
elseif ($IsLinux) {
    $hubPath = "/usr/bin/unityhub"
    $editorRootPath = "$HOME/Unity/Hub/Editor/"
    $editorFileEx = "/Editor/Unity"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('linux-il2cpp', 'android', 'ios')
    }

    # xvfb-run --auto-servernum "$HOME/Unity Hub/UnityHub.AppImage" --headless help
    function Invoke-UnityHub {
        $argsList = $args.Split(" ")
        xvfb-run --auto-servernum "$hubPath" --disable-gpu-sandbox --headless $argsList
    }
}
else {
    Write-Error "Unsupported platform: $($global:PSVersionTable.Platform)"
    exit 1
}

# Install hub if not found
if ( -not (Test-Path -Path "$hubPath") ) {
    Write-Host "Downloading Unity Hub..."
    $baseUrl = "https://public-cdn.cloud.unity3d.com/hub/prod";
    $outPath = $PSScriptRoot
    $wc = New-Object System.Net.WebClient

    if ($IsWindows) {
        Write-Host "::group::Installing Unity Hub on windows..."
        $wc.DownloadFile("$baseUrl/UnityHubSetup.exe", "$outPath/UnityHubSetup.exe")
        $startProcessArgs = @{
            'FilePath'     = "$outPath/UnityHubSetup.exe";
            'ArgumentList' = @('/S');
            'PassThru'     = $true;
            'Wait'         = $true;
        }

        # Run Installer
        $process = Start-Process @startProcessArgs

        if ( $process.ExitCode -ne 0) {
            Write-Error "$(Get-Date): Failed with exit code: $($process.ExitCode)"
            exit 1
        }
    }
    elseif ($IsMacOS) {
        Write-Host "::group::Installing Unity Hub on macOS..."
        $package = "UnityHubSetup.dmg"
        $downloadPath = "$outPath/$package"
        $wc.DownloadFile("$baseUrl/$package", $downloadPath)

        if (!(Test-Path $downloadPath)) {
            Write-Error "Failed to download $package"
            exit 1
        }

        $dmgVolume = (sudo hdiutil attach $downloadPath -nobrowse) | Select-String -Pattern '\/Volumes\/.*' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | select-object -first 1
        Write-Host "DMG Volume: $dmgVolume"
        Start-Sleep -Seconds 1

        if ([string]::IsNullOrEmpty($dmgVolume)) {
            Write-Error "Failed to mount DMG volume"
            exit 1
        }

        $dmgAppPath = (sudo find "$dmgVolume" -name "*.app" -print | head -n 1)
        Write-Host "DMG App Path: $dmgAppPath"
        Start-Sleep -Seconds 1

        if (!(Test-Path $dmgAppPath)) {
            Write-Error "Unity Hub app not found at expected path: $dmgAppPath"
            exit 1
        }

        sudo cp -rf $dmgAppPath "/Applications"
        hdiutil unmount $dmgVolume

        if (!(Test-Path $hubPath)) {
            Write-Error "Failed to install Unity Hub"
            exit 1
        }

        Write-Host "Unity Hub installed at $hubPath"

        sudo chmod -R 777 $hubPath
        sudo mkdir -p "/Library/Application Support/Unity"
        sudo chmod -R 777 "/Library/Application Support/Unity"
    }
    elseif ($IsLinux) {
        Write-Host "::group::Installing Unity Hub on ubuntu..."
        sudo sh -c 'echo ""deb https://hub.unity3d.com/linux/repos/deb stable main"" > /etc/apt/sources.list.d/unityhub.list'
        wget -qO - https://hub.unity3d.com/linux/keys/public | sudo apt-key add -
        sudo apt update
        sudo apt install -y unityhub
        $hubPath = which unityhub
        sudo chmod -R 777 $hubPath
    }
    else {
        Write-Error "Unsupported platform: $($global:PSVersionTable.Platform)"
        exit 1
    }

    Write-Host "::endgroup::"
}

if ( -not (Test-Path "$hubPath") ) {
    Write-Error "$hubPath path not found!"
    exit 1
}

Write-Host "Unity Hub found at `"$hubPath`""

Write-Host "::group::Unity Hub Options"
Invoke-UnityHub help
Write-Host "::endgroup::"

# only show errors if github actions debug is enabled
#if ($env:GITHUB_ACTIONS -eq 'true') {
#    Invoke-UnityHub --errors
#}

# set the editor path
$editorPath = "{0}{1}{2}" -f $editorRootPath, $unityVersion, $editorFileEx

# if architecture is set, check if the specific architecture is installed
if (-not [string]::IsNullOrEmpty($architecture)) {
    # if an editor path is found, check which architecture it is
    if (Test-Path -Path $editorPath) {
        # list all editor installations and pick the ones with the matching version from the returned console output
        $archEditors = Invoke-UnityHub editors -i | Select-String -Pattern "$unityVersion" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }

        # iterate over the editors and check if the version name contains (Intel) for x86_64 or (Apple silicon) for arm64
        foreach ($archEditor in $archEditors) {
            Write-Host "::debug::$archEditor"

            if ($IsMacOS) {
                if ((($archEditor.Contains("(Intel)") -and $architecture -eq 'x86_64')) -or ($archEditor.Contains("(Apple silicon)") -and $architecture -eq 'arm64')) {
                    # set the editor path based on the editor string that was found using a substring. Split subtring by ',' and take the last element
                    $editorPath = $archEditor.Substring(0, $archEditor.IndexOf(','))
                }
            }
            else {
                Write-Error "Architecture lookup not supported for $($global:PSVersionTable.Platform)"
                exit 1
            }
        }
    }
}

function Invoke-Hub-Install($installModules, $installArgs) {
    foreach ($module in $installModules) {
        $installArgs += '-m'
        $installArgs += $module
        Write-Host "  > with module: $module"
    }

    $installArgsString = $installArgs -join " "

    Write-Host "::group::Run unity-hub $installArgsString"
    Invoke-UnityHub $installArgsString
    Write-Host ""
    Write-Host "::endgroup::"
}

function AddModules {
    $addModules = @()

    foreach ($module in $modules) {
        $addModules += $module
        if ($module -eq 'android') {
            $jdkModule = $modules | Where-Object { $_ -like 'android-open-jdk*' }
            if (-not ($modules | Where-Object { $_ -eq $jdkModule })) {
                $addModules += $jdkModule
            }
            $ndkModule = $modules | Where-Object { $_ -like 'android-sdk-ndk-tools*' }
            if (-not ($modules | Where-Object { $_ -eq $ndkModule })) {
                $addModules += $ndkModule
            }
        }
    }

    return $addModules
}

if (-not (Test-Path -Path $editorPath)) {
    Write-Host "Installing $unityVersion ($unityVersionChangeSet)"
    $installArgs = @('install', "--version $unityVersion", "--changeset $unityVersionChangeSet", '--cm')
    $installModules = AddModules

    if (-not [string]::IsNullOrEmpty($architecture)) {
        $installArgs += "-a $architecture"
    }

    Invoke-Hub-Install $installModules $installArgs
}
else {
    Write-Host "Checking modules for $unityVersion ($unityVersionChangeSet)"
    $installArgs = @('install-modules', "--version $unityVersion", '--cm')
    $installModules = AddModules

    if ($installModules.Count -gt 0) {
        Invoke-Hub-Install $installModules $installArgs
    }
}

Write-Host "Installed Editors:"
Invoke-UnityHub editors -i

if (-not (Test-Path -Path $editorPath)) {
    Write-Error "Failed to validate installed editor path at $editorPath"
    exit 1
}

$modulesPath = '{0}{1}/modules.json' -f $editorRootPath, $UnityVersion

if (-not (Test-Path -Path $modulesPath)) {
    $editorPath = "{0}{1}" -f $editorRootPath, $unityVersion
    Write-Error "Failed to resolve modules path at $modulesPath"

    if (Test-Path -Path $editorPath) {
        Get-ChildItem $editorPath
    }

    exit 1
}

Write-Host "Modules Manifest: "$modulesPath

foreach ($module in (Get-Content -Raw -Path $modulesPath | ConvertFrom-Json -AsHashTable)) {
    if (($module.category -eq 'Platforms') -and ($module.visible -eq $true)) {
        if (-not ($modules -contains $module.id)) {
            Write-Host "  > additional module option: " $module.id
        }
    }
}

$envEditorPath = $env:UNITY_EDITOR_PATH

if ([String]::IsNullOrEmpty($envEditorPath)) {
    Write-Host ""
    $editorPath = $editorPath -replace '\\', '/'
    "UNITY_EDITOR_PATH=$editorPath" >> $env:GITHUB_ENV
    Write-Host "UnityEditor path set to: $editorPath"
}

exit 0