# Fix for -> Write-Error: Failed to generate the compressed file for module 'Cannot index into a null array.'.
$env:DOTNET_CLI_UI_LANGUAGE="en_US"


Test-ModuleManifest -Path ".\XAMLgui\XAMLgui.psd1"
pause
Publish-Module -Path ".\XAMLgui" -NuGetApiKey $env:NUGET_API_KEY -Verbose

<#
# find module
Find-Module XAMLgui

# install test
Install-Module XAMLgui -Scope CurrentUser

# Import test
Import-Module XAMLgui
#>



<# 
New-ModuleManifest -Path ".\XAMLgui\XAMLgui.psd1" `
    -RootModule "XAMLgui.psm1" `
    -Author "Nabil Redmann (BananaAcid)" `
    -Description "Kick off a new window from a Visual Studio created XAML file and attach handlers - the easy way 🚀" `
    -CompanyName "Nabil Redmann" `
    -ModuleVersion "1.1.0" `
    -FunctionsToExport "*" `
    -PowerShellVersion "5.1"
#>

<#
xaml gui visual-studio dotnet powershell wpf desktop-application rapid-prototyping powershell-module ui-framework xaml-gui
#>

<#
Invoke-PS2EXE -InputFile "MyScript.ps1" -OutputFile "MyApp.exe" -Title "Custom Title" -Description "My Branded App"
#>