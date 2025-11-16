@{
    RootModule        = 'MyCustomPrompt.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b1e2c3d4-5678-4321-abcd-1234567890ab'
    Author            = 'Luca Papagni'
    CompanyName       = ''
    Copyright         = '(c) 2025 Luca Papagni. All rights reserved.'
    Description       = 'Customizes the PowerShell prompt with indicators, colors, and Git integration.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Get-CustomPrompt', 'Set-CustomPromptOption', 'Get-CustomPromptOptions')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{}
}
