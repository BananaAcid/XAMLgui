<#
  Example: MINI
#>

Import-Module -Name XAMLgui

Hide-Console | Out-Null

# auto add handler by window class name and element Event 
# <Window x:Class="ProjectTest1.MainWindow" ...>
#    <Button click="btnHelloWorld_Click">click me</Button>
function ProjectTest1.MainWindow.btnHelloWorld_Click {
    Show-MessageBox "Hello World!"
}

. New-Window .\MainWindow.xaml -Debug | Show-Window