<#
.SYNOPSIS
  Sync GitHub Issues (epics + stories) from docs/ai_backlog.md.

.DESCRIPTION
  - Creates/updates labels (optional)
  - Creates epic issues (optional)
  - Creates one issue per story (optional)
  - Links story issues back into their epic issues (optional)

  Designed to be idempotent: safe to run repeatedly as the backlog grows.

.REQUIREMENTS
  - GitHub CLI: https://cli.github.com/ (gh)
  - Authenticated gh session with repo access

.EXAMPLE
  ./scripts/sync-ai-backlog-issues.ps1 -All

.EXAMPLE
  ./scripts/sync-ai-backlog-issues.ps1 -CreateStories -LinkStoriesToEpics

.EXAMPLE
  ./scripts/sync-ai-backlog-issues.ps1 -All -DryRun
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter()] [string] $BacklogPath = "docs/ai_backlog.md",
  [Parameter()] [switch] $CreateLabels,
  [Parameter()] [switch] $CreateEpics,
  [Parameter()] [switch] $CreateStories,
  [Parameter()] [switch] $LinkStoriesToEpics,
  [Parameter()] [switch] $All,
  [Parameter()] [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($All) {
  $CreateLabels = $true
  $CreateEpics = $true
  $CreateStories = $true
  $LinkStoriesToEpics = $true
}

function Assert-Command([string] $Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found on PATH: $Name"
  }
}

function Assert-GhAuth {
  $null = gh auth status 2>$null
}

function Read-Backlog([string] $Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Backlog file not found: $Path"
  }
  return Get-Content -LiteralPath $Path
}

function Parse-Backlog($Lines) {
  $epics = @()
  $stories = @()

  $currentEpic = $null
  $currentEpicTitle = $null

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    $line = $Lines[$i]

    if ($line -match '^##\s+EPIC\s+([A-Z]+-\d+):\s*(.+)$') {
      $currentEpic = $Matches[1]
      $currentEpicTitle = $Matches[2].Trim()

      # Gather epic goal line if present
      $goal = $null
      for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
        $next = $Lines[$j].Trim()
        if ($next -match '^\*\*Goal\*\*:\s*(.+)$') {
          $goal = $Matches[1].Trim()
          break
        }
        if ($next -match '^###\s+Story\s+' -or $next -match '^##\s+EPIC\s+') { break }
      }

      $epics += [pscustomobject]@{
        Code = $currentEpic
        Title = $currentEpicTitle
        Goal = $goal
      }

      continue
    }

    if ($line -match '^###\s+Story\s+([A-Z]+-\d+\.\d+)\s+—\s+(.+)$') {
      if (-not $currentEpic) {
        throw "Story appears before any epic header: $line"
      }

      $code = $Matches[1]
      $title = $Matches[2].Trim()

      $ac = @()
      $inAc = $false

      for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
        $next = $Lines[$j]

        if ($next -match '^###\s+' -or $next -match '^##\s+') { break }

        if ($next -match '^\*\*Acceptance criteria\*\*') {
          $inAc = $true
          continue
        }

        if ($inAc) {
          if ($next -match '^-\s+') {
            $ac += $next.Trim()
            continue
          }

          if ($next.Trim() -eq '') {
            break
          }
        }
      }

      $stories += [pscustomobject]@{
        Epic = $currentEpic
        Code = $code
        Title = $title
        AC = $ac
      }

      continue
    }
  }

  return [pscustomobject]@{ Epics = $epics; Stories = $stories }
}

function Get-OpenIssues {
  $json = gh issue list --state open --limit 500 --json number,title,url
  return ($json | ConvertFrom-Json)
}

function Find-IssueByTitlePrefix($Issues, [string] $Prefix) {
  return $Issues | Where-Object { $_.title -like "$Prefix*" } | Select-Object -First 1
}

function Ensure-Labels([switch] $DoIt, [switch] $DryRunMode) {
  if (-not $DoIt) { return }

  $desired = @(
    @{ Name='epic';           Color='5319E7'; Description='Large initiative spanning multiple stories' },
    @{ Name='ai';             Color='0052CC'; Description='AI/LLM related' },
    @{ Name='ml';             Color='006B75'; Description='Machine learning' },
    @{ Name='platform';       Color='0E8A16'; Description='Platform/infrastructure' },
    @{ Name='ocr';            Color='FBCA04'; Description='Receipt OCR/extraction' },
    @{ Name='chat';           Color='D4C5F9'; Description='Chat assistant' },
    @{ Name='embeddings';     Color='1D76DB'; Description='Vector embeddings/search' },
    @{ Name='recommendations';Color='BFD4F2'; Description='Recommendations/ranking' },
    @{ Name='optimization';   Color='FEF2C0'; Description='Optimization/solver' },
    @{ Name='forecasting';    Color='C2E0C6'; Description='Forecasting/time series' },
    @{ Name='evaluation';     Color='F9D0C4'; Description='Evaluation/regression/cost controls' }
  )

  $existing = gh label list --limit 500 | Out-String

  foreach ($l in $desired) {
    $name = $l.Name
    if ($existing -match "(?m)^$([Regex]::Escape($name))\s+") {
      continue
    }

    if ($DryRunMode) {
      Write-Host "[DRY RUN] Would create label: $name"
      continue
    }

    gh label create $name --color $l.Color --description $l.Description | Out-Null
    Write-Host "Created label: $name"
  }
}

function Epic-Labels([string] $EpicCode) {
  $map = @{
    'AIP-01'  = 'epic,ai,platform'
    'RCP-01'  = 'epic,ai,ml,ocr'
    'AST-01'  = 'epic,ai,chat'
    'EMB-01'  = 'epic,ai,embeddings'
    'REC-01'  = 'epic,ai,recommendations'
    'OPT-01'  = 'epic,ai,optimization'
    'FRC-01'  = 'epic,ai,forecasting'
    'EVAL-01' = 'epic,ai,evaluation'
  }

  if (-not $map.ContainsKey($EpicCode)) {
    return 'epic,ai'
  }

  return $map[$EpicCode]
}

function Story-Labels([string] $EpicCode) {
  # Same labels as epic but without the 'epic' label
  return (Epic-Labels $EpicCode).Replace('epic,','')
}

function Ensure-Epics($Epics, [switch] $DoIt, [switch] $DryRunMode) {
  if (-not $DoIt) { return }

  $issues = Get-OpenIssues

  foreach ($epic in $Epics) {
    $prefix = "$($epic.Code): "
    $existing = Find-IssueByTitlePrefix $issues $prefix

    if ($existing) {
      continue
    }

    $labels = Epic-Labels $epic.Code

    $goalLine = if ($epic.Goal) { "Goal: $($epic.Goal)" } else { "Goal: (see docs/ai_backlog.md)" }

    $body = @"
$goalLine

Stories:
- [ ] (run story sync to expand)

Source: docs/ai_backlog.md
"@

    $title = "$($epic.Code): $($epic.Title)"

    if ($DryRunMode) {
      Write-Host "[DRY RUN] Would create epic issue: $title"
      continue
    }

    $url = (gh issue create --title $title --label $labels --body $body).Trim()
    Write-Host "Created epic: $url"
  }
}

function Ensure-Stories($Stories, [switch] $DoIt, [switch] $DryRunMode) {
  if (-not $DoIt) { return @{} }

  $issues = Get-OpenIssues

  # Build epic code -> number mapping
  $epicToNumber = @{}
  foreach ($issue in $issues) {
    foreach ($epicCode in @('AIP-01','RCP-01','AST-01','EMB-01','REC-01','OPT-01','FRC-01','EVAL-01')) {
      if ($issue.title -like "${epicCode}:*") {
        $epicToNumber[$epicCode] = [int]$issue.number
      }
    }
  }

  $epicToStoryNums = @{}

  foreach ($story in $Stories) {
    $prefix = "$($story.Code) — "
    $existing = Find-IssueByTitlePrefix $issues $prefix

    if (-not $epicToStoryNums.ContainsKey($story.Epic)) { $epicToStoryNums[$story.Epic] = @() }

    if ($existing) {
      $epicToStoryNums[$story.Epic] += [int]$existing.number
      continue
    }

    if (-not $epicToNumber.ContainsKey($story.Epic)) {
      throw "Missing epic issue for $($story.Epic). Run with -CreateEpics first."
    }

    $epicNum = $epicToNumber[$story.Epic]
    $labels = Story-Labels $story.Epic

    $acBlock = if ($story.AC.Count -gt 0) { ($story.AC -join "`n") } else { "- (none captured)" }

    $body = @"
Relates to epic #$epicNum.

Acceptance criteria:
$acBlock

Source: docs/ai_backlog.md
"@

    $title = "$($story.Code) — $($story.Title)"

    if ($DryRunMode) {
      Write-Host "[DRY RUN] Would create story issue: $title"
      continue
    }

    $url = (gh issue create --title $title --label $labels --body $body).Trim()
    if ($url -notmatch '/issues/(\d+)$') {
      throw "Unexpected gh output: $url"
    }

    $num = [int]$Matches[1]
    $epicToStoryNums[$story.Epic] += $num
    Write-Host "Created story: $url"
  }

  return $epicToStoryNums
}

function Link-StoriesToEpics($EpicToStoryNums, [switch] $DoIt, [switch] $DryRunMode) {
  if (-not $DoIt) { return }

  if (-not $EpicToStoryNums -or $EpicToStoryNums.Keys.Count -eq 0) {
    Write-Host "No story issues found to link."
    return
  }

  $issues = Get-OpenIssues

  foreach ($epicCode in $EpicToStoryNums.Keys) {
    $epicIssue = $issues | Where-Object { $_.title -like "${epicCode}:*" } | Select-Object -First 1
    if (-not $epicIssue) { throw "Epic issue not found for $epicCode" }

    $epicNumber = [int]$epicIssue.number
    $body = gh issue view $epicNumber --json body -q .body

    $markerStart = '<!-- story-issues-start -->'
    $markerEnd   = '<!-- story-issues-end -->'

    $storyNums = $EpicToStoryNums[$epicCode] | Sort-Object -Unique

    # Build a story list with titles (best-effort)
    $storyLines = @()
    foreach ($n in $storyNums) {
      $storyIssue = $issues | Where-Object { $_.number -eq $n } | Select-Object -First 1
      $t = if ($storyIssue) { $storyIssue.title } else { "#$n" }
      $storyLines += "- [ ] #$n $t"
    }

    $replacement = @(
      $markerStart,
      'Story issues:',
      $storyLines,
      $markerEnd
    ) -join "`n"

    $newBody = $null

    if ($body -match [regex]::Escape($markerStart)) {
      # Replace existing block
      $pattern = "(?s)" + [regex]::Escape($markerStart) + ".*?" + [regex]::Escape($markerEnd)
      $newBody = [regex]::Replace($body, $pattern, $replacement)
    } else {
      # Append new block
      $newBody = $body + "`n`n" + $replacement + "`n"
    }

    if ($DryRunMode) {
      Write-Host "[DRY RUN] Would update epic #$epicNumber ($epicCode) with story links"
      continue
    }

    gh issue edit $epicNumber --body $newBody | Out-Null
    Write-Host "Updated epic #$epicNumber with story links"
  }
}

# --- main ---
Assert-Command gh
Assert-GhAuth

$lines = Read-Backlog $BacklogPath
$parsed = Parse-Backlog $lines

if ($parsed.Stories.Count -eq 0) {
  throw "No stories parsed from $BacklogPath"
}

Ensure-Labels -DoIt:$CreateLabels -DryRunMode:$DryRun
Ensure-Epics -Epics $parsed.Epics -DoIt:$CreateEpics -DryRunMode:$DryRun
$epicToStory = Ensure-Stories -Stories $parsed.Stories -DoIt:$CreateStories -DryRunMode:$DryRun
Link-StoriesToEpics -EpicToStoryNums $epicToStory -DoIt:$LinkStoriesToEpics -DryRunMode:$DryRun

Write-Host "Done."