[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Agent,
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

# The npx entry point exposes the POSIX flag names on every platform, so
# guidance has to name the flags the caller actually typed.
$flagNames = if ($env:PHILOMATHEIA_CLI -eq 'npx') {
    @{ Agent = '--agent'; Destination = '--dest-root'; All = '--all'; Update = '--update' }
}
else {
    @{ Agent = '-Agent'; Destination = '-DestinationRoot'; All = '-All'; Update = '-Update' }
}

$configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
# Three directories cover the ecosystem. `.agents/skills` is the cross-agent
# convention most tools read; Claude Code and the XDG-style agents share the
# other two. Each agent below is mapped to the directory its own documentation
# names, so selecting several agents usually resolves to a single install.
$crossAgentDir = Join-Path $HOME (Join-Path '.agents' 'skills')
$claudeDir = Join-Path $HOME (Join-Path '.claude' 'skills')
$configAgentDir = Join-Path $configHome (Join-Path 'agents' 'skills')

function New-Agent {
    param([string]$Slug, [string]$Name, [string]$Marker, [string]$Root)
    [pscustomobject]@{ Slug = $Slug; Name = $Name; Marker = $Marker; Root = $Root }
}

$knownAgents = @(
    New-Agent 'claude-code' 'Claude Code' (Join-Path $HOME '.claude') $claudeDir
    New-Agent 'codex' 'Codex CLI' (Join-Path $HOME '.codex') $crossAgentDir
    New-Agent 'cursor' 'Cursor' (Join-Path $HOME '.cursor') $crossAgentDir
    New-Agent 'gemini' 'Gemini CLI' (Join-Path $HOME '.gemini') $crossAgentDir
    New-Agent 'copilot' 'GitHub Copilot / VS Code' (Join-Path $HOME '.copilot') $crossAgentDir
    New-Agent 'opencode' 'OpenCode' (Join-Path $configHome 'opencode') $crossAgentDir
    New-Agent 'amp' 'Amp' (Join-Path $configHome 'amp') $configAgentDir
    New-Agent 'goose' 'Goose' (Join-Path $configHome 'goose') $configAgentDir
    New-Agent 'roo' 'Roo Code' (Join-Path $HOME '.roo') $crossAgentDir
    New-Agent 'factory' 'Factory droid' (Join-Path $HOME '.factory') $crossAgentDir
    New-Agent 'pi' 'pi' (Join-Path $HOME '.pi') $crossAgentDir
    New-Agent 'openclaw' 'OpenClaw' (Join-Path $HOME '.openclaw') $crossAgentDir
)

$selectedSlugs = [System.Collections.Generic.List[string]]::new()
$roots = [System.Collections.Generic.List[string]]::new()

function Get-AgentStatus {
    param([object]$Target)

    if (Test-Path -LiteralPath (Join-Path $Target.Root $skillName)) { return 'installed' }
    if (Test-Path -LiteralPath $Target.Marker -PathType Container) { return 'found, not installed' }
    return 'not found'
}

function Write-AgentTable {
    param([switch]$Numbered)

    $nameWidth = ($knownAgents.Name | Measure-Object -Property Length -Maximum).Maximum
    for ($i = 0; $i -lt $knownAgents.Count; $i++) {
        $target = $knownAgents[$i]
        $prefix = if ($Numbered) { '{0,3}) ' -f ($i + 1) } else { '  ' }
        Write-Host ('{0}{1}  {2}' -f $prefix, $target.Name.PadRight($nameWidth), (Get-AgentStatus $target))
    }
}

function Add-Root {
    param([string]$Path)
    if (-not $roots.Contains($Path)) { $roots.Add($Path) }
}

function Select-Agent {
    param([string]$Slug)

    $target = $knownAgents | Where-Object { $_.Slug -eq $Slug } | Select-Object -First 1
    if (-not $target) { return $false }
    if (-not $selectedSlugs.Contains($Slug)) { $selectedSlugs.Add($Slug) }
    Add-Root $target.Root
    return $true
}

function Get-ServedNames {
    param([string]$Path)

    $names = $knownAgents |
        Where-Object { $selectedSlugs.Contains($_.Slug) -and $_.Root -eq $Path } |
        Select-Object -ExpandProperty Name
    return ($names -join ', ')
}

function Write-Destination {
    param([string]$Verb, [string]$Path)

    Write-Host "$Verb $skillName at $(Join-Path $Path $skillName)"
    $served = Get-ServedNames -Path $Path
    if ($served) { Write-Host "  serves $served" }
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

function Confirm-Replacement {
    param([string]$Path)

    while ($true) {
        $answer = Read-Host "$Path already holds an installation. Replace it? [y/N]"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(n|no)$') { return $false }
        if ($answer -match '^(y|yes)$') { return $true }
    }
}

function Select-Destinations {
    $projectIndex = $knownAgents.Count + 1
    $customIndex = $knownAgents.Count + 2

    Write-Host "Select where to install $skillName. Nothing is selected by default."
    Write-Host ''
    Write-Host '     AGENT                     STATUS'
    Write-AgentTable -Numbered
    Write-Host ''
    Write-Host ('{0,3}) {1}' -f $projectIndex, 'This project only (.\.agents\skills)')
    Write-Host ('{0,3}) {1}' -f $customIndex, 'Another directory (enter the path yourself)')
    Write-Host ''

    while ($true) {
        $answer = Read-Host 'Numbers separated by commas (for example 1,2), or Enter to cancel'
        if ([string]::IsNullOrWhiteSpace($answer)) { return $false }

        $tokens = $answer -split '[,\s]+' | Where-Object { $_ }
        $pending = [System.Collections.Generic.List[string]]::new()
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
                $pending.Add('=' + $custom.Trim())
            }
            elseif ($number -eq $projectIndex) {
                $pending.Add('=' + (Join-Path (Get-Location).Path (Join-Path '.agents' 'skills')))
            }
            else {
                $pending.Add($knownAgents[$number - 1].Slug)
            }
        }
        if (-not $valid) { continue }
        if ($pending.Count -eq 0) {
            Write-Host 'Nothing selected.'
            continue
        }

        foreach ($entry in $pending) {
            if ($entry.StartsWith('=')) { Add-Root $entry.Substring(1) }
            else { [void](Select-Agent $entry) }
        }
        return $true
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
    Write-AgentTable
    return
}

foreach ($slug in @($Agent | Where-Object { $_ })) {
    if (-not (Select-Agent $slug)) {
        throw "Unknown agent: $slug. Known agents: $(($knownAgents.Slug) -join ', ')"
    }
}
foreach ($root in @($DestinationRoot | Where-Object { $_ })) {
    Add-Root $root
}

if ($All) {
    foreach ($target in $knownAgents) {
        # Presence of the agent, not of an earlier install: a directory that
        # several agents read must not imply that all of them are here.
        if (Test-Path -LiteralPath $target.Marker -PathType Container) {
            [void](Select-Agent $target.Slug)
        }
    }
    if ($roots.Count -eq 0) {
        throw "No known agent was found on this machine, so $($flagNames.All) selected nothing. Pass $($flagNames.Agent) NAME or $($flagNames.Destination) PATH instead."
    }
}

$interactiveSelection = $false
if ($roots.Count -eq 0) {
    if ($env:PHILOMATHEIA_DEST_ROOT) {
        Add-Root $env:PHILOMATHEIA_DEST_ROOT
    }
    elseif (Test-Interactive) {
        $interactiveSelection = $true
        if (-not (Select-Destinations) -or $roots.Count -eq 0) {
            Write-Host 'Nothing selected. No changes were made.'
            return
        }
    }
    else {
        Write-Host 'No destination was selected, and this session cannot prompt for one.'
        Write-Host 'Agents on this machine:'
        Write-AgentTable
        [Console]::Error.WriteLine("Choose with $($flagNames.Agent) NAME, $($flagNames.Destination) PATH, or $($flagNames.All), or run the installer interactively.")
        exit 2
    }
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

    Write-Destination -Verb $(if ($replacing) { 'Updated' } else { 'Installed' }) -Path $Root
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
    Write-Host 'Most agents detect a new skill automatically. Restart the agent if it does not appear.'
    Write-Host 'Then ask it to teach or map a subject, or invoke the skill by name: philomatheia'
}
