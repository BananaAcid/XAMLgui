# Scopes: New-Window and handlers

## Function signature:
- handler will be bound if they include the window class name and element's event name
    - Example: `<Button click="btnHelloWorld_Click">click me</Button>`
- If the window has a class name, it must preceed the function event name
    - if `<Window x:Class="ProjectTest1.MainWindow" ...>`
    - Example: 
        ```ps1
        Function ProjectTest1.MainWindow.btnHelloWorld_Click {

        }
        ```
    - Example:
        ```ps1
        Function ProjectTest1.MainWindow.btnHelloWorld_Click($Sender, $EventArgs) {

        }
        ```


## To make them accessible, these are your options

1. Handlers with dot-sourced `New-Window`
    ```powershell
    Function Updater.MainWindow.DoActions_Click {
        Show-MessageBox "1"
    }

    $Elements,$MainWindow = . New-Window $XamlFile -Debug
    ```

2. Handler in scriptblock of `New-Window` -- The Handlers scriptblock will be called in the isolated `New-Window` scope
    ```powershell
    $Elements,$MainWindow = New-Window $XamlFile -Debug -Handlers {
        Function Updater.MainWindow.DoActions_Click {
            Show-MessageBox "2"
        }
    }
    ```

3. Global Handlers with `New-Window`
    ```powershell
    Function global:Updater.MainWindow.DoActions_Click {
        Show-MessageBox "3"
    }

    $Elements,$MainWindow = New-Window $XamlFile -Debug
    ```

4. Add Handlers to elements directly
    ```powershell
    $Elements,$MainWindow = New-Window $XamlFile -Debug

    $Elements.DoActions.Add_Click({
        Show-MessageBox "4"
    })
    ```
    - This case really relevant, if you have event names, that are not in the XAMLgui's events list
        - To view them use: `Get-KnownEvents`
