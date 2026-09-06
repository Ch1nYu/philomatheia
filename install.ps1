[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$DestinationRoot,
    [switch]$Update,
    [switch]$All,
    [switch]$ListTargets
)

$ErrorActionPreference = 'Stop'

$skillName = 'philomatheia'
$sourcePath = $PSScriptRoot
$sourceManifest = Join-Path $sourcePath 'SKILL.md'
$runtimeFiles = @('SKILL.md')
$runtimeDirectories = @('agents', 'assets', 'references')
$runtimeScripts = @('init_project.py', 'validate_state.py')

# Harnesses this installer can recognise. Marker is the directory the harness
# owns; Root is the personal skills directory inside it. Recognition never
# implies selection: a destination is used only when it is chosen explicitly.
# The npx entry point exposes the POSIX flag names on every platform, so
# guidance has to name the flags the caller actually typed.
$flagNames = if ($env:PHILOMATHEIA_CLI -eq 'npx') {
    @{ Destination = '--dest-root'; All = '--all'; Update = '--update' }
}
else {
    @{ Destination = '-DestinationRoot'; All = '-All'; Update = '-Update' }
}

$knownHarnesses = @(
    [pscustomobject]@{
        Name   = 'Codex'
        Marker = Join-Path $HOME '.agents'
        Root   = Join-Path $HOME (Join-Path '.agents' 'skills')
    }
    [pscustomobject]@{
        Name   = 'Claude Code'
        Marker = Join-Path $HOME '.claude'
        Root   = Join-Path $HOME (Join-Path '.claude' 'skills')
    }
)

function Get-HarnessTarget {
    foreach ($harness in $knownHarnesses) {
        $installed = Test-Path -LiteralPath (Join-Path $harness.Root $skillName)
        $present = Test-Path -LiteralPath $harness.Marker -PathType Container
        if ($installed) {
            $status = 'installed'
        }
        elseif ($present) {
            $status = 'detected, not installed'
        }
        else {
            $status = 'harness not found'
        }
        [pscustomobject]@{
            Name      = $harness.Name
            Root      = $harness.Root
            Present   = $present
            Installed = $installed
            Status    = $status
        }
    }
}

function Write-TargetTable {
    param([object[]]$Targets, [switch]$Numbered)

    $nameWidth = ($Targets.Name | Measure-Object -Property Length -Maximum).Maximum
    $rootWidth = ($Targets.Root | Measure-Object -Property Length -Maximum).Maximum
    for ($i = 0; $i -lt $Targets.Count; $i++) {
        $target = $Targets[$i]
        $prefix = if ($Numbered) { '{0,3}) ' -f ($i + 1) } else { '  ' }
        Write-Host ('{0}{1}  {2}  {3}' -f $prefix, $target.Name.PadRight($nameWidth), $target.Root.PadRight($rootWidth), $target.Status)
    }
}

function Test-Interactive {
    if ($env:PHILOMATHEIA_NON_INTERACTIVE) { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    try {
        if ([Console]::IsInputRedirected) { return $false }
    }
    catch {
        return $false
    }
    return $true
}

function Select-DestinationRoots {
    $targets = @(Get-HarnessTarget)
    $customIndex = $targets.Count + 1

    Write-Host "Select where to install $skillName. Nothing is selected by default."
    Write-Host ''
    Write-TargetTable -Targets $targets -Numbered
    Write-Host ('{0,3}) {1}' -f $customIndex, 'Another directory (enter the path yourself)')
    Write-Host ''

    while ($true) {
        $answer = Read-Host 'Numbers separated by commas (for example 1,2), or Enter to cancel'
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return @()
        }

        $tokens = $answer -split '[,\s]+' | Where-Object { $_ }
        $chosen = [System.Collections.Generic.List[string]]::new()
        $valid = $true
        foreach ($token in $tokens) {
            $number = 0
            if (-not [int]::TryParse($token, [ref]$number) -or $number -lt 1 -or $number -gt $customIndex) {
                Write-Host "Not a listed choice: $token"
                $valid = $false
                break
            }
            if ($number -eq $customIndex) {
                $custom = Read-Host 'Skills directory path'
                if ([string]::IsNullOrWhiteSpace($custom)) {
                    Write-Host 'No path given.'
                    $valid = $false
                    break
                }
                $chosen.Add($custom.Trim())
            }
            else {
                $chosen.Add($targets[$number - 1].Root)
            }
        }
        if (-not $valid) { continue }

        $unique = @($chosen | Select-Object -Unique)
        if ($unique.Count -eq 0) {
            Write-Host 'Nothing selected.'
            continue
        }
        return $unique
    }
}

function Confirm-Replacement {
    param([string]$Path)

    while ($true) {
        $answer = Read-Host "$Path already holds an installation. Replace it? [y/N]"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(n|no)$') { return $false }
        if ($answer -match '^(y|yes)$') { return $true }
    }
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

if ($ListTargets) {
    Write-TargetTable -Targets @(Get-HarnessTarget)
    return
}

$interactiveSelection = $false
if ($DestinationRoot) {
    $roots = @($DestinationRoot | Where-Object { $_ } | Select-Object -Unique)
}
elseif ($env:PHILOMATHEIA_DEST_ROOT) {
    $roots = @($env:PHILOMATHEIA_DEST_ROOT)
}
elseif ($All) {
    $roots = @(Get-HarnessTarget | Where-Object { $_.Present -or $_.Installed } | Select-Object -ExpandProperty Root)
    if ($roots.Count -eq 0) {
        throw "No known harness directory exists, so $($flagNames.All) selected nothing. Pass $($flagNames.Destination) with the skills directory to use."
    }
}
elseif (Test-Interactive) {
    $roots = @(Select-DestinationRoots)
    $interactiveSelection = $true
    if ($roots.Count -eq 0) {
        Write-Host 'Nothing selected. No changes were made.'
        return
    }
}
else {
    Write-Host 'No destination was selected, and this session cannot prompt for one.'
    Write-Host 'Known harness directories:'
    Write-TargetTable -Targets @(Get-HarnessTarget)
    [Console]::Error.WriteLine("Choose a destination with $($flagNames.Destination), install into every detected harness with $($flagNames.All), or run the installer interactively.")
    exit 2
}

foreach ($root in $roots) {
    if ($Update -or $WhatIfPreference) { break }
    $existing = Join-Path $root $skillName
    if (-not (Test-Path -LiteralPath $existing)) { continue }
    if ($interactiveSelection) {
        if (Confirm-Replacement -Path $existing) { continue }
        Write-Host 'Cancelled. No changes were made.'
        return
    }
    throw "Destination already exists: $existing. Re-run with $($flagNames.Update) to replace the installed skill."
}

function Install-Skill {
    param([string]$Root)

    $destinationPath = Join-Path $Root $skillName
    $replacing = Test-Path -LiteralPath $destinationPath
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

    Write-Host "$($(if ($replacing) { 'Updated' } else { 'Installed' })) $skillName at $destinationPath"
}

$changed = $false
foreach ($root in $roots) {
    $destinationPath = Join-Path $root $skillName
    $operation = if (Test-Path -LiteralPath $destinationPath) { "Update $skillName" } else { "Install $skillName" }
    if ($PSCmdlet.ShouldProcess($destinationPath, $operation)) {
        Install-Skill -Root $root
        $changed = $true
    }
}

if ($changed) {
    Write-Host 'Most harnesses detect a new skill automatically. Restart the agent if it does not appear.'
    Write-Host 'Then ask it to teach or map a subject, or invoke the skill by name: philomatheia'
}
