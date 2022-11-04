param(
    [String]$versionFile,
    [String]$modulesList
)
# Unity Editor Installation
Write-Host "::group::Unity Editor Installation"
$modules = $modulesList.Split(" ")

if ( -not (Test-Path -Path $versionFile) ) {
    Write-Error "Failed to find a valid project version file at `"$versionFile`""
    exit 1
}

$projectPath = (Get-Item $versionFile).Directory.Parent.FullName
Write-Host "Unity project path: `"$projectPath`""
"UNITY_PROJECT_PATH=$projectPath" >> $env:GITHUB_ENV

$version = Get-Content $versionFile
$pattern = '(?<version>(?:(?<major>\d+)\.)?(?:(?<minor>\d+)\.)?(?:(?<patch>\d+[fab]\d+)\b))|((?:\((?<revision>\w+))\))'
$vMatches = [regex]::Matches($version, $pattern)
$unityVersion = $vMatches[1].Groups['version'].Value.Trim()
$unityVersionChangeSet = $vMatches[2].Groups['revision'].Value.Trim()

if ( (-not $global:PSVersionTable.Platform) -or ($global:PSVersionTable.Platform -eq "Win32NT") ) {
    $hubPath = "C:\Program Files\Unity Hub\Unity Hub.exe"
    $editorRootPath = "C:\Program Files\Unity\Hub\Editor\"
    $editorFileEx = "\Editor\Unity.exe"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('windows-il2cpp', 'universal-windows-platform', 'lumin', 'webgl', 'android', 'ios')
    }

    #"Unity Hub.exe" -- --headless help
    #. 'C:\Program Files\Unity Hub\Unity Hub.exe' -- --headless help
    function Invoke-UnityHub {
        $p = Start-Process -Verbose -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList (@('--','--headless') + $args.Split(" "))
        $p.WaitForExit()
    }
}
elseif ( $global:PSVersionTable.OS.Contains("Darwin") ) {
    $hubPath = "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
    $editorRootPath = "/Applications/Unity/Hub/Editor/"
    $editorFileEx = "/Unity.app/Contents/MacOS/Unity"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('mac-il2cpp', 'ios', 'lumin', 'webgl', 'android')
    }

    # /Applications/Unity\ Hub.app/Contents/MacOS/Unity\ Hub -- --headless help
    #. "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless help
    function Invoke-UnityHub {
        $p = Start-Process -Verbose -NoNewWindow -PassThru -Wait -FilePath "$hubPath" -ArgumentList (@('--','--headless') + $args.Split(" "))
        $p.WaitForExit()
    }
}
elseif ( $global:PSVersionTable.OS.Contains("Linux") ) {
    $hubPath = "$HOME/Unity Hub/UnityHub.AppImage"
    $editorRootPath = "$HOME/Unity/Hub/Editor/"
    $editorFileEx = "/Editor/Unity"

    if ([string]::IsNullOrEmpty($modulesList)) {
        $modules = @('linux-il2cpp', 'webgl', 'android', 'ios')
    }

    # /UnityHub.AppImage --headless help
    # xvfb-run --auto-servernum "$HOME/Unity Hub/UnityHub.AppImage" --headless help
    function Invoke-UnityHub {
        xvfb-run --auto-servernum "$hubPath" --headless $args.Split(" ")
    }
}

# Install hub if not found
if ( -not (Test-Path -Path "$hubPath") ) {
    Write-Host "$(Get-Date): Downloading Unity Hub..."
    $baseUrl = "https://public-cdn.cloud.unity3d.com/hub/prod";
    $outPath = $PSScriptRoot
    $wc = New-Object System.Net.WebClient

    Write-Host "$(Get-Date): Download Complete, Starting installation..."

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
    }
    elseif ($global:PSVersionTable.OS.Contains("Linux")) {
        mkdir -pv "$HOME/Unity Hub" "$HOME/.config/Unity Hub" "$editorRootPath"
        sudo apt-get update
        sudo apt-get install -y libgconf-2-4 libglu1 libasound2 libgtk2.0-0 libgtk-3-0 libnss3 zenity xvfb

        #https://www.linuxdeveloper.space/install-unity-linux/
        $wc.DownloadFile("$baseUrl/UnityHub.AppImage", "$hubPath")
        chmod -v a+x "$hubPath"
        touch "$HOME/.config/Unity Hub/eulaAccepted"
    }
}

if ( -not (Test-Path "$hubPath") ) {
    Write-Error "$hubPath path not found!"
    exit 1
}

Write-Host "Unity Hub found at `"$hubPath`""
Write-Host ""

Write-Host "Editor root path currently set to: `"$editorRootPath`""
Write-Host ""

Invoke-UnityHub help
Write-Host ""

$editorPath = "{0}{1}{2}" -f $editorRootPath,$unityVersion,$editorFileEx

if ( -not (Test-Path -Path $editorPath)) {
    Write-Host "Installing $unityVersion ($unityVersionChangeSet)..."
    $installArgs = @('install',"--version $unityVersion","--changeset $unityVersionChangeSet",'--cm')

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
        Write-Host "  with module: $module"
    }

    $installArgsString = $installArgs -join " "

    Invoke-UnityHub $installArgsString
}

Write-Host ""
Invoke-UnityHub editors -i
Write-Host ""

if ( -not (Test-Path -Path $editorPath) ) {
    Write-Error "Failed to validate installed editor path at $editorPath"
    exit 1
}

$modulesPath = '{0}{1}{2}modules.json' -f $editorRootPath,$UnityVersion,[IO.Path]::DirectorySeparatorChar

if ( -not (Test-Path -Path $modulesPath)) {
    $editorPath = "{0}{1}" -f $editorRootPath,$unityVersion
    Write-Host "Cleaning up invalid installation under $editorPath"

    Write-Error "Failed to resolve modules path at $modulesPath"

    if (Test-Path -Path $editorPath) {
        ls $editorPath
        # Remove-Item $editorPath -Recurse -Force
    }

    exit 1
}

Write-Host "Modules Manifest: "$modulesPath
Write-Host ""

foreach ($module in (Get-Content -Raw -Path $modulesPath | ConvertFrom-Json -AsHashTable)) {
    if ( ($module.category -eq 'Platforms') -and ($module.visible -eq $true) ) {
        if ( -not ($modules -contains $module.id) ) {
            Write-Host "additional module option: " $module.id
        }
    }
}

Write-Host ""
Write-Host "UnityEditor path set to: $editorPath"
"UNITY_EDITOR_PATH=$editorPath" >> $env:GITHUB_ENV
Write-Host "::endgroup::"
exit 0