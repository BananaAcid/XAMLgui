<#
  Example
#>
Param(
    $XamlFile = ".\MainWindow.xaml"
)


# this will not allow autobinding of handlers (unless they are in the same scope as with sourcing the ps1 below)
#Import-Module -Name .\XAML.GUI-framework.ps1 -Force -Verbose

# this will allow binding handlers like `function Updater.MainWindow.DoSoftwareDir_Click($Sender, $EventArgs) { ... }`
Import-Module -Name XAMLgui


# pretty up message boxes
Enable-VisualStyles

# early config handling
Hide-Console | Out-Null

# other functions:
#$selectedFolder = Select-FolderDialog
#$selectedFiles = Select-FileDialog
#Invoke-BalloonTip "Example message"
#$job = Start-AwaitJob -scriptBlock ... [-await $True]   # if you set '-await $False', use 'Wait-AwaitJob'
#Wait-AwaitJob $job
#Show-Console
#New-ClonedObjectStruct
#Get-VisualChildren
#Get-CellItemByName
#... and more for internal use


## Binding

# Events like 'Click', 'MouseDown' and more (as in $knownEvents), will be auto attached, if XAML.GUI is invoked in the same scope.
#  That means it needs the script to be invoked with ` . ./main.ps1` (sourcing) not just ` ./main.ps1` --- or load the module by `. ./XAML.GUI-framework.ps1` and not Import-Module
#  The handlers for this have to be available before invoking New-Window.

# Otherwise, you can attach your Events yourself on all found elements in $Elements, which is returned from New-Window.


# auto add handler by window class name and element Event 
# <Window x:Class="Updater.MainWindow" ...>
#    <Label HorizontalAlignment="Right" MouseDown="LbCopy_MouseDown" Cursor="Hand" Foreground="Blue">© Nabil Redmann 2019</Label>
function Updater.MainWindow.LbCopy_MouseDown($Sender, $EventArgs) {
    Show-MessageBox "0.1"
    #Invoke-BalloonTip "abc"
}

# if 
# <Window  ...>  # without class
function LbCopy_MouseDown($Sender, $EventArgs) {
    Show-MessageBox "0.2"
}

# Load the main gui, get an array of $elements (as in $knownEvents), and a handle to the form itself
# AND provide an optional scriptblock for additional handlers (could also point to a file)
$Elements,$MainWindow = New-Window $XamlFile -Debug -Handlers {
    function Updater.MainWindow.doActions_Click {
        Write-Host "doActions_Click"
        Show-MessageBox "0.3"
    }
}

# DEBUG *ELEMENTS: 
Write-Host "`n All `$Elements.* :" ; $Elements | Format-Table



# Add a handler to an initialized window by element's name
# <Button x:Name="doInstall" Content="run all" Width="75" VerticalAlignment="Center" />
$Elements.doInstall.Add_Click({
    Show-MessageBox "1"
})
if ($Elements.Button_AD10EE03_1) {
    $Elements.Button_AD10EE03_1.Add_Click({
        Invoke-BalloonTip "pressed Button_AD10EE03_1"
    })
}

# Add a handler to an initialized window by element's class name and event name to open a new window
$Elements.doInstallAll.Add_Click({
    $Elements2,$MainWindow2 = New-Window $XamlFile

    # required because of the scope by the closure of addClosing()
    $script:MainWindow2 = $MainWindow2

    # close the second window if the main window is closed
    $MainWindow.add_Closing({
        if ($script:MainWindow2.IsLoaded) { $script:MainWindow2.Close() }
    })

    $MainWindow2 | Show-Window -dialog $False
})


# Add a handler to an initialized window, and open a folder and file dialog
$Elements.doOpenConfig.Add_Click({
    $folders = Select-FolderDialog -Title "Select config folder"
    Write-Host "Selected folder:", $folders

    $files = Select-FileDialog -Title "Select config file" -Filter "INI (*.ini)|*.ini" -Path $folder
    Write-Host "Selected files:", ($files | ConvertTo-Json)
})



# In case not all events have been found, add to the already defined list (Add-KnownEvents), or redefine your own list of events to detect within the xaml (Set-KnownEvents will overwrites the hardcoded one)
# Add-KnownEvents @("Click", "CustomEvent", ...)


Write-Host "Waiting for main window to close."
$MainWindow | Show-Window