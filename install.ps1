[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$DestinationRoot,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'

$skillName = 'philomatheia'
$sourcePath = $PSScriptRoot
$sourceManifest = Join-Path $sourcePath 'SKILL.md'
$runtimeFiles = @('SKILL.md')
$runtimeDirectories = @('agents', 'assets', 'references')
$runtimeScripts = @('init_project.py', 'validate_state.py')

function Resolve-DestinationRoots {
    if ($DestinationRoot) {
        return @($DestinationRoot | Where-Object { $_ } | Select-Object -Unique)
    }
    if ($env:PHILOMATHEIA_DEST_ROOT) {
        return @($env:PHILOMATHEIA_DEST_ROOT)
    }

    # Every known harness directory that already exists. Keys are the marker
    # directory the harness owns; values are the skills root inside it.
    $known = [ordered]@{
        (Join-Path $HOME '.agents') = Join-Path $HOME (Join-Path '.agents' 'skills')
        (Join-Path $HOME '.claude') = Join-Path $HOME (Join-Path '.claude' 'skills')
    }
    $found = @()
    foreach ($marker in $known.Keys) {
        if (Test-Path -LiteralPath $marker -PathType Container) {
            $found += $known[$marker]
        }
    }
    if ($found.Count -gt 0) {
        return $found
    }
    return @(Join-Path $HOME (Join-Path '.agents' 'skills'))
}

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

$roots = Resolve-DestinationRoots

if (-not $Update) {
    foreach ($root in $roots) {
        $existing = Join-Path $root $skillName
        if (Test-Path -LiteralPath $existing) {
            throw "Destination already exists: $existing. Re-run with -Update to replace the installed skill."
        }
    }
}

function Install-Skill {
    param([string]$Root)

    $destinationPath = Join-Path $Root $skillName
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $stagingPath = Join-Path $Root ('.philomatheia-stage-' + [guid]::NewGuid().ToString('N'))
    $backupPath = Join-Path $Root ('.philomatheia-old-' + [guid]::NewGuid().ToString('N'))

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
}

$changed = $false
foreach ($root in $roots) {
    $destinationPath = Join-Path $root $skillName
    $operation = if ($Update) { "Update $skillName" } else { "Install $skillName" }
    if ($PSCmdlet.ShouldProcess($destinationPath, $operation)) {
        Install-Skill -Root $root
        $changed = $true
    }
}

if ($changed) {
    Write-Host 'Most harnesses detect a new skill automatically. Restart the agent if it does not appear.'
    Write-Host 'Then ask it to teach or map a subject, or invoke the skill by name: philomatheia'
}
