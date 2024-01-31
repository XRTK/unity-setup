param(
    [String]$versionFilePath,
    [String]$modulesList,
    [String]$architecture
)
# Unity Editor Installation
$modules = $modulesList.Split(" ")
$projectPath = $env:UNITY_PROJECT_PATH

if ([String]::IsNullOrEmpty($projectPath)) {
    if ( -not (Test-Path -Path $versionFilePath) ) {
        Write-Error "Failed to find a valid project version file at `"$versionFilePath`""
        exit 1
    }

    $projectPath = (Get-Item $versionFilePath).Directory.Parent.FullName
    Write-Host "Unity project path: `"$projectPath`""
    "UNITY_PROJECT_PATH=$projectPath" >> $env:GITHUB_ENV
}

$version = Get-Content $versionFilePath
$pattern = '(?<version>(?:(?<major>\d+)\.)?(?:(?<minor>\d+)\.)?(?:(?<patch>\d+[fab]\d+)\b))|((?:\((?<revision>\w+))\))'
$vMatches = [regex]::Matches($version, $pattern)
$unityVersion = $vMatches[1].Groups['version'].Value.Trim()
$unityVersionChangeSet = $vMatches[2].Groups['revision'].Value.Trim()

if ( -not ([String]::IsNullOrEmpty($unityVersion))) {
    Write-Host ""
    "UNITY_EDITOR_VERSION=$unityVersion" >> $env:GITHUB_ENV
    Write-Host "Unity Editor version set to: $unityVersion"
}

if ( (-not $global:PSVersionTable.Platform) -or ($global:PSVersionTable.Platform -eq "Win32NT") ) {
    $hubPath = "C:\Program Files\Unity Hub\Unity Hub.exe"
    $editorRootPath = "C:\Program Files\Unity\Hub\Editor\"
    $editorFileEx = "\Editor\Unity.exe"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('windows-il2cpp', 'universal-windows-platform', 'android', 'ios')
    }

    #"Unity Hub.exe" -- --headless help
    #. 'C:\Program Files\Unity Hub\Unity Hub.exe' -- --headless help
    function Invoke-UnityHub {
        $argList = (@('--','--headless') + $args.Split(" "))
        $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList $argList
        $p.WaitForExit()
    }
}
elseif ( $global:PSVersionTable.OS.Contains("Darwin") ) {
    $hubPath = "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
    $editorRootPath = "/Applications/Unity/Hub/Editor/"
    $editorFileEx = "/Unity.app/Contents/MacOS/Unity"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('mac-il2cpp', 'ios', 'android')
    }

    # /Applications/Unity\ Hub.app/Contents/MacOS/Unity\ Hub -- --headless help
    #. "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless help
    function Invoke-UnityHub {
        $argList = (@('--','--headless') + $args.Split(" "))
        $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList $argList
        $p.WaitForExit()
    }
}
elseif ( $global:PSVersionTable.OS.Contains("Linux") ) {
    $hubPath = "/usr/bin/unityhub"
    $editorRootPath = "$HOME/Unity/Hub/Editor/"
    $editorFileEx = "/Editor/Unity"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('linux-il2cpp', 'android', 'ios')
    }

    # /UnityHub.AppImage --headless help
    # xvfb-run --auto-servernum "$HOME/Unity Hub/UnityHub.AppImage" --headless help
    function Invoke-UnityHub {
        $argsList = $args.Split(" ")
        xvfb-run --auto-servernum "$hubPath" --disable-gpu-sandbox --headless $argsList
    }
}

# Install hub if not found
if ( -not (Test-Path -Path "$hubPath") ) {
    Write-Host "Downloading Unity Hub..."
    $baseUrl = "https://public-cdn.cloud.unity3d.com/hub/prod";
    $outPath = $PSScriptRoot
    $wc = New-Object System.Net.WebClient

    Write-Host "::group::Installing Unity Hub..."

    if ((-not $global:PSVersionTable.Platform) -or ($global:PSVersionTable.Platform -eq "Win32NT")) {
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
    elseif ($global:PSVersionTable.OS.Contains("Darwin")) {
        $package = "UnityHubSetup.dmg"
        $downloadPath = "$outPath/$package"
        $wc.DownloadFile("$baseUrl/$package", $downloadPath)

        $dmgVolume = (sudo hdiutil attach $downloadPath -nobrowse) | Select-String -Pattern '\/Volumes\/.*' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | select-object -first 1
        Write-Host $dmgVolume
        $dmgAppPath = (find "$DMGVolume" -name "*.app" -depth 1)
        Write-Host $dmgAppPath
        sudo cp -rf "`"$dmgAppPath`"" "/Applications"
        hdiutil unmount $dmgVolume
        sudo mkdir -p "/Library/Application Support/Unity"
        sudo chmod 775 "/Library/Application Support/Unity"
        touch '/Library/Application Support/Unity/temp'
    }
    elseif ($global:PSVersionTable.OS.Contains("Linux")) {
        sudo sh -c 'echo ""deb https://hub.unity3d.com/linux/repos/deb stable main"" > /etc/apt/sources.list.d/unityhub.list'
        wget -qO - https://hub.unity3d.com/linux/keys/public | sudo apt-key add -
        sudo apt update
        sudo apt install -y unityhub
        which unityhub
    }

    Write-Host "::endgroup::"
}

if ( -not (Test-Path "$hubPath") ) {
    Write-Error "$hubPath path not found!"
    exit 1
}

Write-Host "Unity Hub found at `"$hubPath`""

# Write-Host "Editor root path currently set to: `"$editorRootPath`""

Write-Host "::group::Unity Hub Options"
Invoke-UnityHub help
Write-Host "::endgroup::"

# only show errors if github actions debug is enabled
#if ($env:GITHUB_ACTIONS -eq 'true') {
#    Invoke-UnityHub --errors
#}

# set the editor path
if ([string]::IsNullOrEmpty($architecture)) {
    $editorPath = "{0}{1}{2}" -f $editorRootPath,$unityVersion,$editorFileEx
} else {
    $editorPath = "{0}{1}-{2}{3}" -f $editorRootPath,$unityVersion,$architecture,$editorFileEx
}

if (-not (Test-Path -Path $editorPath)) {
    Write-Host "Installing $unityVersion ($unityVersionChangeSet)"
    $installArgs = @('install',"--version $unityVersion","--changeset $unityVersionChangeSet",'--cm')

    if (-not [string]::IsNullOrEmpty($architecture)) {
        $installArgs += "-a $architecture"
    }

    $addModules = @()

    foreach ($module in $modules) {
        if ($module -eq 'android') {
            $addmodules += 'android-open-jdk'
            $addmodules += 'android-sdk-ndk-tools'
        }
    }

    $modules += $addModules

    foreach ($module in $modules) {
        $installArgs += '-m'
        $installArgs += $module
        Write-Host "  > with module: $module"
    }

    $installArgsString = $installArgs -join " "

    Write-Host "::group::Run unity-hub $installArgsString"
    Invoke-UnityHub $installArgsString
    Write-Host ""
    Write-Host "::endgroup::"
} else {
    Write-Host "Intalling modules for $unityVersion ($unityVersionChangeSet)"
    $installArgs = @('install-modules',"--version $unityVersion",'--cm')

    $addModules = @()

    foreach ($module in $modules) {
        if ($module -eq 'android') {
            $addmodules += 'android-open-jdk'
            $addmodules += 'android-sdk-ndk-tools'
        }
    }

    $modules += $addModules

    foreach ($module in $modules) {
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

Write-Host "Installed Editors:"
Invoke-UnityHub editors -i

if (-not (Test-Path -Path $editorPath)) {
    Write-Error "Failed to validate installed editor path at $editorPath"
    exit 1
}

$modulesPath = '{0}{1}{2}modules.json' -f $editorRootPath,$UnityVersion,[IO.Path]::DirectorySeparatorChar

if ( -not (Test-Path -Path $modulesPath)) {
    $editorPath = "{0}{1}" -f $editorRootPath,$unityVersion
    Write-Error "Failed to resolve modules path at $modulesPath"

    if (Test-Path -Path $editorPath) {
        Get-ChildItem $editorPath
    }

    exit 1
}

Write-Host "Modules Manifest: "$modulesPath

foreach ($module in (Get-Content -Raw -Path $modulesPath | ConvertFrom-Json -AsHashTable)) {
    if ( ($module.category -eq 'Platforms') -and ($module.visible -eq $true) ) {
        if ( -not ($modules -contains $module.id) ) {
            Write-Host "  > additional module option: " $module.id
        }
    }
}

$envEditorPath = $env:UNITY_EDITOR_PATH

if ([String]::IsNullOrEmpty($envEditorPath)) {
    Write-Host ""
    "UNITY_EDITOR_PATH=$editorPath" >> $env:GITHUB_ENV
    Write-Host "UnityEditor path set to: $editorPath"
}

exit 0