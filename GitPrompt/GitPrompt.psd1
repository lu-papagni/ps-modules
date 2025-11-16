@{
    RootModule = 'GitPrompt.psm1'
    ModuleVersion = '0.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = 'b1a8e7e2-2b6c-4e9e-9b2e-1a2b3c4d5e6f'
    Author = 'Your Name'
    Description = 'Provides Git status indicators for PowerShell prompts.'
    FunctionsToExport = @('Update-GitCache', 'Set-GitPromptIndicator')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{}
    PowerShellVersion = '7.0'
}
