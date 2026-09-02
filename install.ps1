[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DestinationRoot = (Join-Path $HOME '.agents\skills'),
    [switch]$Update
)

$ErrorActionPreference = 'Stop'

$skillName = 'philomatheia'
$sourcePath = $PSScriptRoot
$sourceManifest = Join-Path $sourcePath 'SKILL.md'
$destinationPath = Join-Path $DestinationRoot $skillName
$runtimeFiles = @('SKILL.md')
$runtimeDirectories = @('agents', 'assets', 'references')
$runtimeScripts = @('init_project.py', 'validate_state.py')

if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
    throw "SKILL.md was not found beside this installer: $sourceManifest"
}
foreach ($item in $runtimeDirectories) {
    $itemPath = Join-Path $sourcePath $item
    if (-not (Test-Path -LiteralPath $itemPath -PathType Container)) {
        throw "Required runtime directory is missing: $itemPath"
    }
}
foreach ($item in $runtimeScripts) {
    $itemPath = Join-Path (Join-Path $sourcePath 'scripts') $item
    if (-not (Test-Path -LiteralPath $itemPath -PathType Leaf)) {
        throw "Required runtime script is missing: $itemPath"
    }
}

if ((Test-Path -LiteralPath $destinationPath) -and -not $Update) {
    throw "Destination already exists: $destinationPath. Re-run with -Update to replace the installed skill."
}

if ($PSCmdlet.ShouldProcess($destinationPath, $(if ($Update) { "Update $skillName" } else { "Install $skillName" }))) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $stagingPath = Join-Path $DestinationRoot ('.philomatheia-stage-' + [guid]::NewGuid().ToString('N'))
    $backupPath = Join-Path $DestinationRoot ('.philomatheia-old-' + [guid]::NewGuid().ToString('N'))

    try {
        New-Item -ItemType Directory -Path $stagingPath | Out-Null
        foreach ($item in $runtimeFiles) {
            $itemPath = Join-Path $sourcePath $item
            if (Test-Path -LiteralPath $itemPath) {
                Copy-Item -LiteralPath $itemPath -Destination $stagingPath
            }
        }
        foreach ($item in $runtimeDirectories) {
            $itemPath = Join-Path $sourcePath $item
            if (Test-Path -LiteralPath $itemPath) {
                Copy-Item -LiteralPath $itemPath -Destination $stagingPath -Recurse
            }
        }
        $stagedScripts = Join-Path $stagingPath 'scripts'
        New-Item -ItemType Directory -Path $stagedScripts | Out-Null
        foreach ($item in $runtimeScripts) {
            $itemPath = Join-Path (Join-Path $sourcePath 'scripts') $item
            if (Test-Path -LiteralPath $itemPath) {
                Copy-Item -LiteralPath $itemPath -Destination $stagedScripts
            }
        }

        $stagedManifest = Join-Path $stagingPath 'SKILL.md'
        if (-not (Test-Path -LiteralPath $stagedManifest -PathType Leaf)) {
            throw "Installation verification failed: $stagedManifest is missing."
        }
        foreach ($item in $runtimeScripts) {
            $stagedScript = Join-Path $stagedScripts $item
            if (-not (Test-Path -LiteralPath $stagedScript -PathType Leaf)) {
                throw "Installation verification failed: $stagedScript is missing."
            }
        }

        if (Test-Path -LiteralPath $destinationPath) {
            Move-Item -LiteralPath $destinationPath -Destination $backupPath
        }
        Move-Item -LiteralPath $stagingPath -Destination $destinationPath

        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Recurse -Force
        }
    }
    catch {
        if ((-not (Test-Path -LiteralPath $destinationPath)) -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $destinationPath
        }
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force
        }
        throw
    }

    $installedManifest = Join-Path $destinationPath 'SKILL.md'
    if (-not (Test-Path -LiteralPath $installedManifest -PathType Leaf)) {
        throw "Installation verification failed: $installedManifest is missing."
    }

    Write-Host "$($(if ($Update) { 'Updated' } else { 'Installed' })) $skillName at $destinationPath"
    Write-Host 'Codex usually detects the skill automatically. Restart Codex if it does not appear.'
    Write-Host 'Invoke it with: $philomatheia'
}
