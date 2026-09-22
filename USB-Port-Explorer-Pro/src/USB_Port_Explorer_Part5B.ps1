<# GitHub source segment 5B; loaded by the root wrapper. Do not run directly. #>
$refreshButton.Add_Click({ Refresh-UsbData })
$exportButton.Add_Click({ Export-UsbCsv })
$searchButton.Add_Click({ Show-UsbTree })
$clearButton.Add_Click({ $script:SearchText.Clear(); Show-UsbTree })
$script:SearchText.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Show-UsbTree
        $eventArgs.SuppressKeyPress = $true
    }
})
$script:Tree.Add_AfterSelect({
    param($sender, $eventArgs)
    if ($null -ne $eventArgs.Node -and $null -ne $eventArgs.Node.Tag) {
        Show-SelectedRecord $eventArgs.Node.Tag
    }
})
$script:SaveLabelButton.Add_Click({ Save-PhysicalLabel })
$script:Form.Add_Shown({
    # Fit the whole window, including its title bar and bottom controls,
    # within this monitor's *working* area (taskbar excluded). This also
    # handles displays where DPI scaling changes the effective frame size.
    $work = [System.Windows.Forms.Screen]::FromControl($script:Form).WorkingArea
    $safeWidth = [Math]::Max(400, [Math]::Min($script:Form.Width, $work.Width - 16))
    $safeHeight = [Math]::Max(360, [Math]::Min($script:Form.Height, $work.Height - 16))
    $script:Form.MinimumSize = [System.Drawing.Size]::new(
        [Math]::Min(700, $safeWidth), [Math]::Min(480, $safeHeight))
    $safeLeft = $work.Left + [Math]::Max(0, [int](($work.Width - $safeWidth) / 2))
    $safeTop = $work.Top + [Math]::Max(0, [int](($work.Height - $safeHeight) / 2))
    $script:Form.Bounds = [System.Drawing.Rectangle]::new(
        $safeLeft, $safeTop, $safeWidth, $safeHeight)

    # Now that Windows Forms has the final dimensions, position the splitter.
    # Avoid startup-only min-size constraints (the original crash).
    $availableWidth = $split.ClientSize.Width - $split.SplitterWidth
    if ($availableWidth -gt 100) {
        $leftWidth = [Math]::Min(460, [Math]::Max(25, $availableWidth - 330))
        $leftWidth = [Math]::Max(25, [Math]::Min($leftWidth, $availableWidth - 25))
        $split.SplitterDistance = [int]$leftWidth
    }
    Refresh-UsbData
})

Initialize-NativeUsbProbe
Import-PortLabels
[void]$script:Form.ShowDialog()
