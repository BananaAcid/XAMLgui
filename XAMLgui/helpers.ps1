<# 
    .Synopsis
        Kick off a new window from PowerShell of a Visual Studio created XAML file and attach handlers - the easy way 🚀

    .Description
        Version 1.1.0
        License MIT
        (c) Nabil Redmann 2019 - 2026
        Supports: Powershell 5+ (including pwsh 7)

    .LINK
        https://gist.github.com/BananaAcid/0484b11a03c03f172740096e213d1d82

    .Notes
        based on https://stackoverflow.com/a/52416973/1644202
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Scope = 'Function', Target = '*')]
Param()

# Enable visual styles, in case there will be a message box or alike
Function Enable-VisualStyles
{
    Add-Type -AssemblyName System.Drawing,System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
}


# .Net methods for hiding/showing the console in the background, https://stackoverflow.com/a/40621143/1644202
Add-Type -Name Window -Namespace XAMLgui_Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

Function Show-Console
{
    Param( [Parameter(Mandatory=$false)]$state=4 )

    $consolePtr = [XAMLgui_Console.Window]::GetConsoleWindow()

    # https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-showwindow
    # Hide = 0,
    # ShowNormal = 1,
    # ShowMinimized = 2,
    # ShowMaximized = 3,
    # Maximize = 3,
    # ShowNormalNoActivate = 4,
    # Show = 5,
    # Minimize = 6,
    # ShowMinNoActivate = 7,
    # ShowNoActivate = 8,
    # Restore = 9,
    # ShowDefault = 10,
    # ForceMinimized = 11

    [XAMLgui_Console.Window]::ShowWindow($consolePtr, $state)
}

Function Hide-Console
{
    # return true/false
    $consolePtr = [XAMLgui_Console.Window]::GetConsoleWindow()
    #0 hide
    [XAMLgui_Console.Window]::ShowWindow($consolePtr, 0)
}

Function Get-PropOrNull
{
    param( $thing, [string]$prop )

    Try {
        $thing.$prop
    } Catch {}
}

# https://gist.github.com/nwolverson/8003100
Function Get-VisualChildren($item)
{
    for ($i = 0; $i -lt [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($item); $i++) {
        $child = [System.Windows.Media.VisualTreeHelper]::GetChild($item, $i)
        Get-VisualChildren($child)
    }
    $item
}

Function Get-CellItemByName
{
    Param
    (
        [ref]$Parent,
        $ItemNo,
        $Name
    )

    [System.Windows.Forms.Application]::DoEvents()

    if ($DebugPreference -ne 'SilentlyContinue') { $Parent.value | Write-Host }

    $items = (Get-VisualChildren ($Parent.Value) |? { $_.GetType().Name -eq "ListViewItem" })

    if ($DebugPreference -ne 'SilentlyContinue') { $items | Write-Host }
    if ($DebugPreference -ne 'SilentlyContinue') { $ItemNo | Write-Host }
    if ($DebugPreference -ne 'SilentlyContinue') { $items[$ItemNo] | Write-Host }

    if ($DebugPreference -ne 'SilentlyContinue') { Get-VisualChildren $items[$ItemNo] | Write-Host }


    return (Get-VisualChildren $items[$ItemNo] |? { $_.Name -eq $Name} | Select-Object -First 1)
}

Function Wait-AwaitJob
{
    Param ( [Parameter(Mandatory=$true)]$Job )

    while ($Job.state -eq 'Running') {
        [System.Windows.Forms.Application]::DoEvents()  # keep form responsive
    }

    # Captures and throws any exception in the job output -> '-ErrorAction stop' --- otherwise returns result
    return Receive-Job $Job -ErrorAction Continue
}

# start and await a job
Function Start-AwaitJob
{
    Param
    (
        [Scriptblock][Parameter(Mandatory=$true)] $ScriptBlock,
        [string[]][Parameter(Mandatory=$false)] $ArgumentList=@(),
        [string][Parameter(Mandatory=$false)] $Dir = "", # sets the current working directory (use it to set the subfolder) !
        [boolean][Parameter(Mandatory=$false)] $Await = $True,
        [string][Parameter(Mandatory=$false)] $InitBlock = ""
    )

    $useDir = $PWD
    If ($Dir -ne "") { $useDir = Resolve-Path $Dir }

    $job = Start-Job -Init ([ScriptBlock]::Create("Set-Location '$($useDir -replace "'", "''")'`n" + $InitBlock)) -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList

    If ($Await) {
        return Wait-AwaitJob $job    
    }
    Else {
        return $job    
    }
}


Function Show-MessageBox
{
    Param
    (
        [string]$Message = "This is a default Message.", 
        [string]$Title = "Default Title", 
        [ValidateSet("Asterisk","Error","Exclamation","Hand","Information","None","Question","Stop","Warning")] 
        [string]$Type = "Error", 
        [ValidateSet("AbortRetryIgnore","OK","OKCancel","RetryCancel","YesNo","YesNoCancel")] 
        [string]$Buttons = "OK" 
    )

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $MsgBoxResult = [System.Windows.Forms.MessageBox]::Show($Message,$Title,[Windows.Forms.MessageBoxButtons]::$Buttons,[Windows.Forms.MessageBoxIcon]::$Type) 

    Return $MsgBoxResult 
}

Function Invoke-BalloonTip
{
    <#
    .Synopsis
        Display a balloon tip message in the system tray.
    .Description
        This function displays a user-defined message as a balloon popup in the system tray. This function
        requires Windows Vista or later.
    .Parameter Message
        The message text you want to display.  Recommended to keep it short and simple.
    .Parameter Title
        The title for the message balloon.
    .Parameter MessageType
        The type of message. This value determines what type of icon to display. Valid values are
    .Parameter SysTrayIcon
        The path to a file that you will use as the system tray icon. Default is the PowerShell ISE icon.
    .Parameter Duration
        The number of seconds to display the balloon popup. The default is 1000.
    .Inputs
        None
    .Outputs
        None
    .Notes
         NAME:      Invoke-BalloonTip
         VERSION:   1.0
         AUTHOR:    Boe Prox

         Modified by Nabil Redmann
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,HelpMessage="The message text to display. Keep it short and simple.")]
        [string]$Message,
        [Parameter(HelpMessage="The message title")]
        [string]$Title="Attention $env:username",
        [Parameter(HelpMessage="The message type: Info,Error,Warning,None")]
        [System.Windows.Forms.ToolTipIcon]$MessageType="Info",
     
        [Parameter(HelpMessage="The path to a file to use its icon in the system tray")]
        [string]$SysTrayIconPath="",
        [Parameter(HelpMessage="The number of milliseconds to display the message.")]
        [int]$Duration=1000
    )
    
    Add-Type -AssemblyName System.Windows.Forms

    If (-NOT $global:balloon) {
        Write-Debug 'Initiating creation of balloon'
        $global:balloon = New-Object System.Windows.Forms.NotifyIcon
        #Mouse double click on icon to dispose
        [void](Register-ObjectEvent -InputObject $balloon -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action {
            #Perform cleanup actions on balloon tip
            Write-Debug 'Disposing of balloon'
            $global:balloon.dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name balloon -Scope Global
        })
    }

    If ($SysTrayIconPath -ne "") {
        $SysTrayIcon = Get-IconFromFile -FilePath $SysTrayIconPath
    }

    # Need an icon for the tray - $SysTrayIcon is null if Get-IconFromFile failed
    If ($SysTrayIconPath -eq "" -or $null -eq $SysTrayIcon) {
        $SysTrayIconPath = Get-Process -id $PID | Select-Object -ExpandProperty Path
        $SysTrayIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($SysTrayIconPath)
    }

    #Extract the icon from the file
    $balloon.Icon = $SysTrayIcon
    #Can only use certain TipIcons: [System.Windows.Forms.ToolTipIcon] | Get-Member -Static -Type Property
    $balloon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]$MessageType
    $balloon.BalloonTipText  = $Message
    $balloon.BalloonTipTitle = $Title
    $balloon.Visible = $true
    #Display the tip and specify in milliseconds on how long balloon will stay visible
    $balloon.ShowBalloonTip($Duration)
    Write-Debug "Ending function"
}

Function Get-IconFromFile
{
    param(
        [string][Parameter(Mandatory=$True)]$FilePath,
        [string][Parameter(Mandatory=$False)]$Type
    )

    If (-not (Test-Path $FilePath)) {
        Write-Warning "Icon file not found at: $FilePath"
        exit 7
    }

    If ($Type -eq "") {
        $Type = (Get-Item $FilePath).Extension.Substring(1)
    }

    If ($Type -eq "bmp" -or $Type -eq "jpg" -or $Type -eq "jpeg" -or $Type -eq "png") {
        $picture = New-Object System.Drawing.Bitmap($FilePath)
    }
    elseif ($Type -eq "ico") {
        return $FilePath
    }
    elseif ($Type -eq "exe") {
        return [System.Drawing.Icon]::ExtractAssociatedIcon($FilePath)
    }
    else {
        return $null
    }

    $iconHandle = $picture.GetHicon()
    # Create a System.Drawing.Icon object from the handle
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $picture.Dispose()

    return $icon
}


Function Select-FolderDialog
{
    Param
    (
        [string]$Title = "Select a Folder",
        [string]$Description = "",
        [string]$Path = [Environment]::GetFolderPath("Desktop"),
        [string]$SelectedPath = "",
        [boolean]$Multiselect = $false,
        [boolean]$ShowNewFolderButton = $false
    )

    Add-Type -AssemblyName System.Windows.Forms  

    if ($Title -ne "" -and $Description -eq "") {
        $Description = $Title
        $UseDescriptionForTitle = $true
    }
    else {
        $UseDescriptionForTitle = $false
    }

    $objForm = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        # https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.folderbrowserdialog?view=windowsdesktop-10.0
        InitialDirectory = $Path
        SelectedPath = $SelectedPath
        Description = $Description
        Multiselect = $Multiselect
        ShowNewFolderButton = $ShowNewFolderButton

        UseDescriptionForTitle = $UseDescriptionForTitle
    }

    $Show = $objForm.ShowDialog()

    If ($Show -eq "OK") {
        Return $objForm.SelectedPaths
    }
    Else {
        Write-Verbose "Select-FolderDialog cancelled by user."
        Return ''
    }
}
# $folder = Select-FolderDialog # the variable contains user folder selection

Function Select-FileDialog
{
    Param
    (
        [string]$Title="Select Folder",
        [string]$Path="Desktop",
        [string]$Filter='Images (*.jpg, *.png)|*.jpg;*.png',
        [boolean]$Multiselect=$false
    )

    Add-Type -AssemblyName System.Windows.Forms

    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Filter = $Filter # Specified file types
        Multiselect = $Multiselect # Multiple files can be chosen
        Title = $Title
        InitialDirectory = $Path
    }
 
    [void]$FileBrowser.ShowDialog()

    If ($FileBrowser.FileNames -like "*\*") {
        # even with multiselect, if only 1 file was selected, it will NOT return an array
        Return $FileBrowser.FileNames
    }
    Else {
        #if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "Cancelled by user" }
        Return ""
    }
}

Function Get-PowershellInterpreter
{
    <#
    .SYNOPSIS
    Returns the powershell interpreter used in the current session, and a list if `poershell.exe` or `pwsh.exe` are available.
    .EXAMPLE
    $current, $available = Get-PowershellInterpreter
    #>
    If ($PSVersionTable.PSEdition -eq "Desktop") {
        $current = "powershell.exe"
    }
    Else { #"Core"
        $current = "pwsh.exe"
    }

    $available = @{
        "powershell.exe" = (Command powershell.exe)
        "pwsh.exe" = (Command pwsh.exe)
    }

    return $current, $available
}

Function Set-RunOnce
{
    <# 
    .SYNOPSIS 
    Sets a Runonce-Registry Key 

    .DESCRIPTION 
    Sets a Runonce-Key in the Computer-Registry. Every Program which will be added will run once at system startup. 
    This Command can be used to configure a computer at startup. 

    .EXAMPLE 
    Set-Runonce -command '%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file c:\Scripts\start.ps1' 
    Sets a Key to run Powershell at startup and execute C:\Scripts\start.ps1 

    .NOTES 
    Author: Holger Voges 
    Version: 1.0 
    Date: 2018-08-17 

    # modified by Nabil Redmann

    .LINK 
    https://www.netz-weise-it.training/ 
    #>
    [CmdletBinding()]
    param
    (
        #The Name of the Registry Key in the Autorun-Key.
        [string]$KeyName = "Run",


        #Command to run
        [string]$Command = "-executionpolicy bypass -file `"$($MyInvocation.ScriptName)`"",

        #Command params to add
        [String]$Params = "",

        #Interpreter to use
        [String]$Interpreter = "powershell.exe"
    )

    $cmdStr = "$($Interpreter) $($Command) $($Params)"

    
    If (-not ((Get-Item -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce).$KeyName )) {
        New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name $KeyName -Value $cmdStr -PropertyType ExpandString -Force
    }
    else {
        Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name $KeyName -Value $cmdStr -PropertyType ExpandString -Force
    }

    return $cmdStr
}

Function New-ClonedObjectDeep
{
    #param([PSCustomObject]$srcObject)
    #return $srcObject.psobject.copy()

    #param([PSCustomObject]$srcObject)
    #deep copy:  return $srcObject | ConvertTo-Json -depth 100 | ConvertFrom-Json

    # deep copy!
    param($srcObject)
    $ms = New-Object System.IO.MemoryStream
    $bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $bf.Serialize($ms, $srcObject)
    $ms.Position = 0
    $copyObject = $bf.Deserialize($ms)
    $ms.Close()

    return $copyObject
}

Function New-ClonedObject
{
    param( [PSCustomObject]$srcObject )

    return $srcObject.psobject.copy() # | ConvertTo-Json -depth 100 | ConvertFrom-Json
}

# To be able to use a local module, because deploying the app on an USB stick
# will need it and might not have internet access
function Find-LocalModulePath {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String] $Name,

        [String] $Path = ".\ps_modules"
    )

    return ls "$Path\$Name" -ErrorAction SilentlyContinue | select -Last 1 |% FullName
}
function Import-LocalModule {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String] $Name,

        [String] $Path = ".\ps_modules",

        [Boolean] $Download = $True
    )

    if (-not (Find-LocalModulePath $Name) -and $Download) { Save-Module -Name $Name -Path $Path }
    $path = Find-LocalModulePath $Name -Path $Path
    if (-not $path) { Write-Error "Unable to find $Name module, could not download. Aborting."; Exit 99 }
}