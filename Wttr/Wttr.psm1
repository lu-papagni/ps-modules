function Get-WeatherReport {
param(
    [string] $Language = $Host.CurrentUICulture.TwoLetterISOLanguageName,
    [int] $TimeoutSec = 3,
    [switch] $Clean,
    [switch] $Color
  )

  if ($Clean) { Remove-OldCacheFiles }

  $cacheFile = Join-Path $env:temp ("wttr_request_{0}" -f (New-Guid).Guid)
  $options = "0npq" 

  $useColor = $Color.IsPresent -or ($Host.UI.SupportsVirtualTerminal -eq $true)
  if (-not $useColor) {
    $options += 'T'
  }

  $requestParameters = @{
    Uri = 'http://wttr.in?lang={0}&{1}' -f $Language, $options;
    TimeoutSec = $TimeoutSec;
    OutFile = $cacheFile
  }

  $needRefresh = Test-Path $cacheFile -OlderThan ((Get-Date).AddSeconds(-$Throttle))
  if (-not (Test-Path $cacheFile) -or $needRefresh) {
    try {
      Invoke-RestMethod @requestParameters
    } catch { }
  }

  if (Test-Path $cacheFile) {
    return $cacheFile | Get-Content -Raw 
  }
  return $null
}

function Remove-OldCacheFiles {
  Get-ChildItem -Path $env:temp -Filter "wttr_request_*" | Remove-Item -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Get-WeatherReport
