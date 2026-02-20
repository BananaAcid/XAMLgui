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

# Enable visual styles, in case there will be a message box or alike
Function Enable-VisualStyles
{
    Add-Type -AssemblyName System.Drawing,System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
}


Function New-Window
{
    Param
    (
        [Parameter(ValueFromPipeline=$True,Mandatory=$True,Position=0)]$xamlFile,
        [Parameter(Mandatory=$False,Position=1)][Alias("Handlers")][AllowNull()]$HandlersScriptBlockOrFile = $Null
    )

    $xamlString = Get-Content -Path $xamlFile
    return New-WindowXamlString $xamlString -Handlers $HandlersScriptBlockOrFile
}

Function New-WindowUrl
{
    Param
    (
        [Parameter(ValueFromPipeline=$True,Mandatory=$True,Position=0)]$url,
        [Parameter(Mandatory=$False,Position=1)][Alias("Handlers")][AllowNull()]$HandlersScriptBlockOrFile = $Null
    )

    $xamlString = (New-Object System.Net.WebClient).DownloadString($url)
    return New-WindowXamlString $xamlString -Handlers $HandlersScriptBlockOrFile
}


$script:knownEvents = @(
    # Some major events. There are way more.
    # Window
    "Initialized", "Loaded", "Unloaded", "Activated", "Closed", "Closing", "GotFocus", "LostFocus", "SizeChanged", "GotFocus", "LostFocus",
    # Checkbox, Buttons etc
    "Click", "Checked", "MouseDoubleClick", "MouseEnter", "MouseLeave", "MouseDown", "MouseUp", "MouseLeftButtonDown", "MouseLeftButtonUp", "MouseRightButtonDown", "MouseRightButtonUp", "MouseMove", "MouseWheel",
    # Text
    "KeyDown", "KeyUp", "PreviewKeyDown", "PreviewKeyUp",
    # Combobox
    "SelectionChanged",
    # Drag and Drop
    "Drop", "DragEnter", "DragLeave",
    # Change events
    "TextChanged", "SelectionChanged", "Checked", "Unchecked", "Collapsed", "Expanded"
);

Function Add-KnownEvents
{
    Param ( [String[]]$EventNames )

    $script:knownEvents += $EventNames
}

Function Set-KnownEvents
{
    Param ( [String[]]$EventNames )

    $script:knownEvents = $EventNames
}


Function New-WindowXamlString
{
    Param
    (
        [Parameter(ValueFromPipeline=$True,Mandatory=$True,Position=0)]$xamlString,
        [Parameter(Mandatory=$False,Position=1)][Alias("Handlers")][AllowNull()]$HandlersScriptBlockOrFile = $Null
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

    If (!$script:knownEvents) { $script:knownEvents = [String[]]@() }

    # prepare window xaml: replace <Win> with <Window>, also allow <Window.Resources>
    $xamlString = $xamlString -replace '<(/?)Win[a-zA-Z]*','<$1Window'

    # store window class
    $windowClass = $null
    $match = [Regex]::Match($xamlString, '^[\s]*<Window[^>]*(x:Class="([^"]*)")', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    # actually not a problem ... do not exit
    if ($match.Success -eq $False) {
        if ($DebugPreference -ne 'SilentlyContinue') { Write-Host '[XAML.GUI] XAML does not contain a <Window x:Class="..."> which is not optimal, if you have multiple windows.' }
        # Exit 4
    }

    if ($match.Captures.Groups.Count -eq 3) {
        
        $windowClass = $match.Captures.Groups[2].Value
        
        if ($windowClass) {
            $xamlString = $xamlString -replace $match.Captures.Groups[1].Value,''
        }
    }

    #===========================================================================
    # fix XAML markup for powershell
    #===========================================================================
    $xamlString = $xamlString -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace "x:n",'N' -replace "x:Bind", "Binding"
    try {
        [xml]$XAML = $xamlString
    }
    catch {
        if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] XAML parsing error" -ForegroundColor Red }
        if ($DebugPreference -ne 'SilentlyContinue') { Write-Host $_.Exception.message -ForegroundColor Red }
        Exit 5
    }

    #===========================================================================
    # storing events
    #===========================================================================
    $generatedCount = @{} # generated name = int
    # Should generate a name based on its outer XML (complete xml line), that is unique and persistent (unless the line is changed)
    Function Get-CRC32Style
    {
        Param ( [string] $inputString )

        [int64]$hash = 0
        [uint32]$mask = 4294967295  # This avoids the "hex-is-negative" bug in PS 5.1 (do not use 0xFFFFFFFF)
        foreach ($char in $inputString.ToCharArray()) {
            $hash = ([long]($hash * 31) + [int][char]$char) -band $mask
        }
        $hashResult = "{0:X8}" -f $hash

        # count generated identical names
        if ($generatedCount[$hashResult]) {
            $generatedCount[$hashResult]++
        } else {
            $generatedCount[$hashResult] = 1
        }

        return [string]$hashResult + "_" + $generatedCount[$hashResult]
    }

    $eventElements = @()
    Foreach ($eventName in $script:knownEvents) {
        Foreach ($node in $XAML.SelectNodes("//*[@$eventName]")) {
            If (!$node.Attributes['Name']) {
                # Needed, because XAML elements will later be matched to the pure XML by name to append the event to the parsed XAML Element
                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Adding NAME to element with event" $node.OuterXml -ForegroundColor Green }
                $name = $node.LocalName + "_" + $(Get-CRC32Style $node.OuterXml) -replace "-","_" #$(Get-Random)  $(New-Guid)
                $node.SetAttribute("Name", $name)

                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] ... Applied new generated Name = $($node.Name)" -ForegroundColor Green }

                <#*NONAME -- works now above (using Get-CRC32Style)
                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Name not set for element $($node.Name) with event $eventName and function $($node.$eventName)" -ForegroundColor Red }
                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "  " $node.OuterXml -ForegroundColor Red }
                # Exit 3
                #>
            }

            #*NONAME If ($node.Attributes['Name']) {
                $eventElements += @{
                    e = $node
                    ev = $eventName
                    fn = $node.$eventName
                    name = $node.Attributes['Name'].Value
                }
            #}

            # PS does not handle events, need to be removed, but were added to the elements collection
            $node.RemoveAttribute($eventName)
        }
    }


    #===========================================================================
    #Read XAML
    #===========================================================================
    $reader = (New-Object System.Xml.XmlNodeReader $XAML)

    try {
        $Form = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch [System.Management.Automation.MethodInvocationException] {
        Write-Warning "[XAML.GUI] We ran into a problem with the XAML code.  Check the syntax for this control..."
        if ($DebugPreference -ne 'SilentlyContinue') { Write-Host $error[0].Exception.Message -ForegroundColor Red }
        Exit 1
    }
    catch {#if it broke some other way
        if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed." }
        Exit 2
    }


    #===========================================================================
    # attaching click handlers
    #===========================================================================
    if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Window class is " $(if ($windowClass) { $windowClass } else { "not set" }) }

    # source handlers from scriptblock if supplied
    if ([string]::IsNullOrWhiteSpace($HandlersScriptBlockOrFile)) { <# param not used. #> }
    elseif (($HandlersScriptBlockOrFile).getType().Name -eq 'ScriptBlock') {
        # Import from scriptblock
        . $HandlersScriptBlockOrFile
    }
    elseif (($HandlersScriptBlockOrFile).getType().Name -eq 'String' -and (Test-Path (Join-Path $PWD $HandlersScriptBlockOrFile) -PathType Leaf)) {
        # Import file if it exists
        . (Join-Path $PWD $HandlersScriptBlockOrFile)
    }
    else {
        Write-Error "Handlers not found: ", $HandlersScriptBlockOrFile
        Exit 6
    }


    Foreach ($evData in $eventElements) {
        $fnName = $evData.fn
        if ($windowClass) {
            $fnName = "$windowClass.$fnName"
        }

        $fns = Get-ChildItem function: | Where-Object { $_.Name -like $fnName } # function namespace.windowclassname.function_name($Sender, $EventArgs)

        if ($evData.name) { $name = $evData.name } else { $name = '-no name-' }
        If (!$fns.Count) {
            if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Linking event $($evData.ev) on element $name -> function $fnName(`$Sender,`$EventArgs) FAILED: no handler" -ForegroundColor Red }
        }
        else {
            if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Linking event $($evData.ev) on element $name -> function $fnName(`$Sender,`$EventArgs)" }

            Invoke-Expression ('$Form.FindName($evData.name).Add_' + $evData.ev + '( $fns[0].ScriptBlock )')
        }
    }

    #===========================================================================
    # Store named elements to be acessable through $Elements
    #===========================================================================
    $Elements = @{}
    #$XAML.SelectNodes("//*[@Name]") | %{Set-Variable -Name "GUI_$($_.Name)" -Value $Form.FindName($_.Name)}
    $XAML.SelectNodes("//*[@Name]") |% { $Elements[$_.Name] = $Form.FindName($_.Name) }

    $Elements["_Window"] = $Form

    return $Elements,$Form
}

Function Show-Window
{
    Param
    (
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] $window,
        $dialog = $True
    )

    $win = $window
    if ($window._Window) {
        $win = $window._Window
    }

    if ($dialog) {
        $win.ShowDialog() | Out-Null
    }
    else {
        $win.Show() | Out-Null
    }
    $global:win = $win
}


# .Net methods for hiding/showing the console in the background, https://stackoverflow.com/a/40621143/1644202
Add-Type -Name Window -Namespace XAML_Gui_Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

Function Show-Console
{
    Param( [Parameter(Mandatory=$false)]$state=4 )

    $consolePtr = [XAML_Gui_Console.Window]::GetConsoleWindow()

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

    [XAML_Gui_Console.Window]::ShowWindow($consolePtr, $state)
}

Function Hide-Console
{
    # return true/false
    $consolePtr = [XAML_Gui_Console.Window]::GetConsoleWindow()
    #0 hide
    [XAML_Gui_Console.Window]::ShowWindow($consolePtr, 0)
}




Function New-ClonedObjectStruct
{
    param( [PSCustomObject]$srcObject )

    return $srcObject.psobject.copy() # | ConvertTo-Json -depth 100 | ConvertFrom-Json
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
    Param ( [Parameter(Mandatory=$true)]$job )

    while ($job.state -eq 'Running') {
        [System.Windows.Forms.Application]::DoEvents()  # keep form responsive
    }

    # Captures and throws any exception in the job output -> '-ErrorAction stop' --- otherwise returns result
    return Receive-Job $job -ErrorAction Continue
}

# start and await a job
Function Start-AwaitJob
{
    Param
    (
        [Parameter(Mandatory=$true)] $scriptBlock,
        [Parameter(Mandatory=$false)] $ArgumentList=@(),
        [Parameter(Mandatory=$false)] $Dir, # sets the current working directory (use it to set the subfolder) !
        [Parameter(Mandatory=$false)] $await = $True
    )

    $useDir = $PWD
    If ($Dir) { $useDir = Resolve-Path $Dir }

    $job = Start-Job -Init ([ScriptBlock]::Create("Set-Location '$($useDir -replace "'", "''")'")) -ScriptBlock $scriptBlock -ArgumentList $ArgumentList

    If ($await) {
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
        [string]$SysTrayIconPath='',
        [Parameter(HelpMessage="The number of milliseconds to display the message.")]
        [int]$Duration=1000
    )
    
    Add-Type -AssemblyName System.Windows.Forms

    If (-NOT $global:balloon) {
        $global:balloon = New-Object System.Windows.Forms.NotifyIcon
        #Mouse double click on icon to dispose
        [void](Register-ObjectEvent -InputObject $balloon -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action {
            #Perform cleanup actions on balloon tip
            Write-Verbose 'Disposing of balloon'
            $global:balloon.dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name balloon -Scope Global
        })
    }

    #Need an icon for the tray
    If ($SysTrayIconPath -eq "") {
        $SysTrayIconPath = Get-Process -id $PID | Select-Object -ExpandProperty Path
    }

    #Extract the icon from the file
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SysTrayIconPath)
    #Can only use certain TipIcons: [System.Windows.Forms.ToolTipIcon] | Get-Member -Static -Type Property
    $balloon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]$MessageType
    $balloon.BalloonTipText  = $Message
    $balloon.BalloonTipTitle = $Title
    $balloon.Visible = $true
    #Display the tip and specify in milliseconds on how long balloon will stay visible
    $balloon.ShowBalloonTip($Duration)
    Write-Verbose "Ending function"
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