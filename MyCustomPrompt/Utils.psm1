function Update-HashtableKeys {
  param (
    [hashtable]$Source,
    [hashtable]$Updates
  )
  foreach ($key in $Updates.Keys) {
    if ($Source.ContainsKey($key)) {
      if ($Source[$key] -is [hashtable] -and $Updates[$key] -is [hashtable]) {
        Update-HashtableKeys -Source $Source[$key] -Updates $Updates[$key]
      } else {
        $Source[$key] = $Updates[$key]
      }
    }
  }
}
Export-ModuleMember -Function Update-HashtableKeys
