# XAML.GUI framework

Kick off a new window from PowerShell of a Visual Studio created XAML file and attach handlers - the easy way 🚀

## 📦 Installation

```powershell
Install-Module -name XAMLgui
```

*Latest version:  https://github.com/BananaAcid/XAMLgui*


<details>
<summary>only download it into your current folder</summary>

```powershell
Save-Module -Name XAMLgui -Path .\   # this creates a subfolder .\XAMLgui\1.1.0\
```
</details>

## 🚀 Usage

```powershell
Import-Module -Name XAMLgui

Hide-Console | Out-Null

Function ProjectTest1.MainWindow.btnHelloWorld_Click {
    Show-MessageBox "Hello World!"
}

. New-Window .\MainWindow.xaml -Debug | Show-Window
```

**About the event handler function:**
- handler will be bound if they include the window class name and element's event name
    - Example: `<Button click="btnHelloWorld_Click">click me</Button>`
- If the window has a class name, it must preceed the function event name
    - `<Window x:Class="ProjectTest1.MainWindow" ...>`
- `New-Window` has to be dot-sourced in this case
- More about using handlers: [docs/README.md](https://github.com/BananaAcid/XAMLgui/blob/main/docs/README.md)


> [!TIP]
> **About the `-Debug` param on New-Window.. functions**
> - Use it!
> - It will show you what elements have been found and what events could be attached


## ⭐ Examples and general documentation

- Quick usage: [docs/example-mini.ps1](https://github.com/BananaAcid/XAMLgui/blob/main/docs/example-mini.ps1)
- More extensive usage: [docs/example-main.ps1](https://github.com/BananaAcid/XAMLgui/blob/main/docs/example-main.ps1)

## ℹ️ Notes

WinUI3 [might be nativly supported](https://blog.nkasco.com/wordpress/index.php/2024/08/27/how-to-use-winui-3-styles-with-wpf-forms-in-powershell-net-9/).

Fluent UI usage (dll, namespace, xaml), see [here](https://blog.nkasco.com/wordpress/index.php/2024/05/21/how-to-use-winui-3-styles-with-wpf-forms-in-powershell/).

For better notification bubbles, use https://github.com/Windos/BurntToast instead of the built-in `Invoke-BalloonTip`

> [!IMPORTANT]
> Use **Visual Studio**, create a WPF-Application (XAML, Desktop), to create a XAML file containing a `<Window>`.
>
> You can use the XAML designer view in Visual Studio to add and arange the components.

## 📝 Changes

### v1.1.1
- added `Set-RunOnce` to run the current or another script once at startup
- added `New-ClonedObjectDeep` to deep clone an object (as long as it is binary serializable)
- renamed `New-ClonedObjectStruct` to `New-ClonedObject`
- added `Get-IconFromFile` for a window icon or notification bubble
- added `Get-KnownEvents` to list events known by XAMLgui
- changed code structure

### v1.1.0
- added better handling of `<Window`
- changed class in `<Window class=""` to be optional (handlers to be attached will not need the class string as prefix, since there is none)
- changed generated names for elements with detected handlers to have a relatively persistent name (based on the elements XML string and its current occurrence's index)
- added an optional param `-Handlers` for a scriptblock or filename with handlers for New-Window* functions
- changed `Select-FolderDialog` to have a proper `-Title` and the path related params are cleaned up
- changed `Select-FileDialog` to handle `-Multiselect` correctly (returns all selected files)
- added more default events
- added `Set-KnownEvents` to overwrite the hardcoded list
- changed `Add-KnownEvents` to add event names to the hardcoded list
- cleanup