$GitPromptIndicators = @{
  Staged     = '+'
  Modified   = '!'
  Untracked  = '?'
  Conflicted = '✗'
  Ahead      = '↑'
  Behind     = '↓'
  StashCount = '*'
}

$GitPromptCache = @{
  LastUpdate   = [datetime]::MinValue
  RepoRoot     = ""
  GitBranch    = $null
  IsRepo       = $false
  GitAvailable = $null
  Status       = @{
    Staged      = 0
    Modified    = 0
    Untracked   = 0
    Ahead       = 0
    Behind      = 0
    StashCount  = 0
    Indicators  = @()
  }
}

function Get-GitRepoRoot {
param(
    [string]$Path,
    [int]$MaxDepth=10
  )

  $current = $Path
  [int]$depth = 0

  while ($current.Length -gt 0 -and $depth -lt $MaxDepth) {
    $gitDir = Join-Path $current '.git'

    if ([System.IO.File]::Exists($gitDir) -or [System.IO.Directory]::Exists($gitDir)) {
      return $current
    }

    $parent = Split-Path $current -ErrorAction SilentlyContinue
    if ($parent -eq $current) { break }  # Prevents infinite loops

    $current = $parent
    $depth++
  }

  return $null
}

function Get-GitBranchFast {
param([string]$RepoRoot)

  $gitDir = Join-Path $RepoRoot '.git'

  # Handles worktree and submodules
  if ([System.IO.File]::Exists($gitDir)) {
    $gitDirContent = Get-Content $gitDir -Raw -ErrorAction SilentlyContinue
    if ($gitDirContent -match 'gitdir: (.+)') {
      $gitDir = Join-Path $RepoRoot $matches[1].Trim()
    }
  }

  $headFile = Join-Path $gitDir 'HEAD'
  if (-not [System.IO.File]::Exists($headFile)) {
    return $null
  }

  $headContent = [System.IO.File]::ReadAllText($headFile).Trim()

  if ($headContent -match '^ref: refs/heads/(.+)$') {
    return $matches[1]
  } elseif ($headContent -match '^[0-9a-f]{40}$') {
    return '@' + $headContent.Substring(0, 7)
  }

  return $null
}

function Update-GitStatus {
param(
    [string]$RepoRoot
  )

  # Reset status
  $status = @{
    Staged      = 0
    Modified    = 0
    Untracked   = 0
    Conflicted  = 0
    Ahead       = 0
    Behind      = 0
    StashCount  = 0
    Indicators  = @()
  }

  # Faster git status with implicit timeout
  $gitOutput = git -C $RepoRoot status --porcelain=v1 -b --ahead-behind 2>$null

  if ($gitOutput) {
    foreach ($line in $gitOutput) {
      if ($line.StartsWith('##')) {
        if ($line -match '\[ahead (\d+)(?:, behind (\d+))?\]') {
          $status.Ahead = [int]$matches[1]
          if ($matches[2]) { $status.Behind = [int]$matches[2] }
        } elseif ($line -match '\[behind (\d+)\]') {
          $status.Behind = [int]$matches[1]
        }
        continue
      }

      $x, $y = $line[0], $line[1]

      if ($x -eq 'U' -or $y -eq 'U') { $status.Conflicted++ }
      if ($x -in 'A', 'M', 'R', 'C', 'D') { $status.Staged++ }
      if ($x -eq '?' -and $y -eq '?') { $status.Untracked++ }
      elseif ($y -in 'M', 'D') { $status.Modified++ }
    }
  }

  # Counts the stashes using rev-list for efficiency
  $stashCountRaw = git -C $RepoRoot rev-list --count refs/stash 2>$null
  $status.StashCount = if ($stashCountRaw) { [int]$stashCountRaw } else { 0 }

  # Indicator construction
  $indicators = @()
  if ($status.Staged -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Staged, $status.Staged
      Color = $PSStyle.Foreground.Yellow
    }
  }
  if ($status.Modified -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Modified, $status.Modified
      Color = $PSStyle.Foreground.BrightYellow
    }
  }
  if ($status.Untracked -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Untracked, $status.Untracked
      Color = $PSStyle.Foreground.Blue
    }
  }
  if ($status.Conflicted -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Conflicted, $status.Conflicted
      Color = $PSStyle.Foreground.Red
    }
  }
  if ($status.Ahead -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Ahead, $status.Ahead
      Color = $PSStyle.Foreground.Green
    }
  }
  if ($status.Behind -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.Behind, $status.Behind
      Color = $PSStyle.Foreground.Green
    }
  }
  if ($status.StashCount -gt 0) {
    $indicators += @{
      Symbol = "{0}{1}" -f $GitPromptIndicators.StashCount, $status.StashCount
      Color = $PSStyle.Foreground.Magenta
    }
  }

  $status.Indicators = $indicators
  $GitPromptCache.Status = $status
}

function Update-GitCache {
param(
    [int]$Throttle=5
  )

  [string]$currentPath = $executionContext.SessionState.Path.CurrentLocation
  $cache = $GitPromptCache

  # Check Git availability
  if ($null -eq $cache.GitAvailable) {
    $cache.GitAvailable = [bool](Get-Command 'git' -ErrorAction SilentlyContinue)
  }

  if (-not $cache.GitAvailable) {
    return $null
  }

  # Find the repository root
  $repoRoot = Get-GitRepoRoot -Path $currentPath
  $now = Get-Date

  # Determine if an update is needed based on repo root change or throttle interval
  [bool]$needsUpdate = ($cache.RepoRoot -ne $repoRoot -or ($now - $cache.LastUpdate).TotalSeconds -gt $Throttle)

  if ($needsUpdate) {
    # Reset cache
    $cache.IsRepo = $false
    $cache.RepoRoot = $null
    $cache.GitBranch = $null
    $cache.Status = @{ Indicators = @() }

    if ($repoRoot) {
      $cache.IsRepo = $true
      $cache.RepoRoot = $repoRoot
      $cache.GitBranch = Get-GitBranchFast -RepoRoot $repoRoot

      # Update status only if branch found
      if ($cache.GitBranch) {
        Update-GitStatus -RepoRoot $repoRoot
      }
    }

    $cache.LastUpdate = $now
  }

  return $cache
}

function Set-GitPromptIndicator {
param(
    [Parameter(Mandatory)]
    [ValidateSet('Staged','Modified','Untracked','Conflicted','Ahead','Behind','StashCount')]
    [string]$Type,
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [char]$Symbol
  )
  $GitPromptIndicators[$Type] = $Symbol
}

Export-ModuleMember -Function Update-GitCache,Set-GitPromptIndicator
