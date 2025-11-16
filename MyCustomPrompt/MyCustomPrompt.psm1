$PSReadLineOptions = Get-PSReadLineOption
$CustomPrompt = @{
  Indicator = @{
    Normal = [char]0x276F;
    Error = [char]0x26A0;
    Multiline = [char]0x21B3;
  };
  Git = @{ Enable = $true; Throttle = 2 };
  Colors = @{
    Reset = $PSStyle.Reset;
    Text = $PSStyle.Foreground.BrightWhite;
    Directory = $PSReadLineOptions.StringColor;
    Arrow = @{
      Ok = $PSReadLineOptions.CommandColor;
      Error = $PSReadLineOptions.ErrorColor;
    };
    Git = @{ Branch = $PSReadLineOptions.KeywordColor }
  };
  MaxRelativePromptLength = 0.6;
}

function Get-CustomPromptOptions {
  return $CustomPrompt
}

function Set-CustomPromptOption {
param (
    [Nullable[double]]$MaxRelativePromptLength,
    [Nullable[char]]$Arrow,
    [Nullable[char]]$ErrorIndicator,
    [Nullable[char]]$MultilineIndicator,
    [Nullable[bool]]$EnableGit,
    [Nullable[int]]$GitThrottle,
    [string]$TextColor,
    [string]$DirectoryColor,
    [string]$ArrowOkColor,
    [string]$ArrowErrorColor,
    [string]$GitBranchColor
  )

  if ($MaxRelativePromptLength -ne $null) {
    $CustomPrompt.MaxRelativePromptLength = $MaxRelativePromptLength
  }
  if ($Arrow -ne $null) {
    $CustomPrompt.Indicator.Normal = $Arrow
  }
  if ($ErrorIndicator -ne $null) {
    $CustomPrompt.Indicator.Error = $ErrorIndicator
  }
  if ($MultilineIndicator -ne $null) {
    $CustomPrompt.Indicator.Multiline = $MultilineIndicator
  }
  if ($EnableGit -ne $null) {
    $CustomPrompt.Git.Enable = $EnableGit
  }
  if ($GitThrottle -ne $null) {
    $CustomPrompt.Git.Throttle = $GitThrottle
  }
  if ($TextColor) {
    $CustomPrompt.Colors.Text = $TextColor
  }
  if ($DirectoryColor) {
    $CustomPrompt.Colors.Directory = $DirectoryColor
  }
  if ($ArrowOkColor) {
    $CustomPrompt.Colors.Arrow.Ok = $ArrowOkColor
  }
  if ($ArrowErrorColor) {
    $CustomPrompt.Colors.Arrow.Error = $ArrowErrorColor
  }
  if ($GitBranchColor) {
    $CustomPrompt.Colors.Git.Branch = $GitBranchColor
  }

  # Reload prompt so that options are always up to date
  $function:prompt = Get-CustomPrompt
}

# Returns a function to use as the prompt
function Get-CustomPrompt {
  $Arrow = $CustomPrompt.Indicator.Normal
  $MultilineIndicator = $CustomPrompt.Indicator.Multiline
  $ErrorIndicator = $CustomPrompt.Indicator.Error
  $ShowGit = $CustomPrompt.Git.Enable
  $GitThrottle = $CustomPrompt.Git.Throttle
  $MaxRelativePromptLength = $CustomPrompt.MaxRelativePromptLength

  $colors = $CustomPrompt.Colors

  $okprompt = '{0}{1}{2} ' -f $colors.Arrow.Ok, $Arrow, $colors.Reset
  $errprompt = '{0}{1}{2} ' -f $PSReadLineOptions.ErrorColor, $ErrorIndicator, $colors.Reset
  Set-PSReadLineOption -PromptText $okprompt, $errprompt
  Set-PSReadLineOption -ContinuationPrompt (' {0}' -f $MultilineIndicator)

  # We return a new closure so that the prompt function captures the current environment and variables,
  # allowing dynamic prompt rendering each time it's called, while maintaining access to local state.
  return {
    # Choose arrow color based on previous command status
    # WARNING: this should be at the top because the last status is overridden by
    # every command
    $arrowColor = if ($?) { $colors.Arrow.Ok } else { $colors.Arrow.Error }

    [string]$currentPath = $executionContext.SessionState.Path.CurrentLocation
    $workDir = $currentPath -replace [regex]::Escape($env:USERPROFILE), '~'
    $windowWidth = $Host.UI.RawUI.WindowSize.Width
    $maxPromptWidth = [math]::Floor($windowWidth * $MaxRelativePromptLength)

    $gitInfo = ""
    if ($ShowGit) {
      $gitCache = & (Get-Command Update-GitCache -Scope Global -ErrorAction Stop) -Throttle $GitThrottle

      if ($gitCache.IsRepo -and $gitCache.GitBranch) {
        $gitInfoBuilder = [System.Text.StringBuilder]::new("")
        [void]$gitInfoBuilder.AppendFormat(' {0}on {1}{2}', $colors.Text, $colors.Git.Branch, $gitCache.GitBranch)

        $indicatorCount = $gitCache.Status.Indicators.Count 
        for ([int]$i=0; $i -lt $indicatorCount; $i++) {
          $indicator = $gitCache.Status.Indicators[$i]
          [void]$gitInfoBuilder.AppendFormat(' {0}{1}', $indicator.Color, $indicator.Symbol)
        }
        $gitInfo = $gitInfoBuilder.ToString()
      }
    }

    # Truncate the working directory path if it's too long to fit in the prompt
    $maxCwdWidth = $maxPromptWidth - $gitInfo.Length
    if ($workDir.Length -gt $maxCwdWidth) {
      $workDir = "..." + $workDir.Substring($workDir.Length - $maxCwdWidth + 3)
    }

    $promptBuilder = [System.Text.StringBuilder]::new("")
    [void]$promptBuilder.AppendFormat('{0}{1}', $colors.Directory, $workDir)
    [void]$promptBuilder.Append($gitInfo)
    [void]$promptBuilder.AppendFormat(" {0}{1}{2} ", $arrowColor, $Arrow, $colors.Reset)

    return $promptBuilder.ToString()
  }.GetNewClosure()
}

Export-ModuleMember -Function Get-CustomPrompt, Set-CustomPromptOption, Get-CustomPromptOptions

