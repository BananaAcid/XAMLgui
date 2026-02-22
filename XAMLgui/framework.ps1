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

Function Get-KnownEvents
{
    return $script:knownEvents
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
                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Adding NAME to element with event" $node.OuterXml -ForegroundColor Yellow }
                $name = $node.LocalName + "_" + $(Get-CRC32Style $node.OuterXml) -replace "-","_" #$(Get-Random)  $(New-Guid)
                $node.SetAttribute("Name", $name)

                if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] ... Applied new generated Name = $($node.Name)" -ForegroundColor Yellow }

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
        # 1. Execute it locally so the module can use them internally if needed
        . $HandlersScriptBlockOrFile

        # 2. Use the AST (Abstract Syntax Tree) to find all functions defined in the block
        $funcs = $HandlersScriptBlockOrFile.Ast.FindAll({
            $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)
        # 3. Force-inject them into the Script scope (Better globally?)
        $funcs |% { Set-Item -Path "function:script:$($_.Name)" -Value $_.Body.GetScriptBlock() }
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

        #$fns = Get-ChildItem function: | Where-Object { $_.Name -like $fnName } # function namespace.windowclassname.function_name($Sender, $EventArgs)

        $fns = Get-Item function:$fnName -ErrorAction SilentlyContinue
        if (!$fns) { $fns = Get-Item function:global:$fnName -ErrorAction SilentlyContinue; }

        if ($evData.name) { $name = $evData.name } else { $name = '-no name-' }
        If (!$fns.Count) {
            if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Linking event $($evData.ev) on element $name -> function $fnName(`$Sender,`$EventArgs) FAILED: no handler" -ForegroundColor Red }
        }
        else {
            if ($DebugPreference -ne 'SilentlyContinue') { Write-Host "[XAML.GUI] Linking event $($evData.ev) on element $name -> function $fnName(`$Sender,`$EventArgs)" -ForegroundColor Green }

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
