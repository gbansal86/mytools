<# GitHub source segment 5A; loaded by the root wrapper. Do not run directly. #>
<#
Source module 5 of 5 for USB Port Explorer Pro.
This file is loaded by USB_Port_Explorer.ps1. Run the root launcher rather than this module directly.
The split keeps the project easier to read on GitHub; functional statements are kept in original order.
#>

$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = 'USB Port Explorer Pro - USB topology + easy physical-port guide'
$script:Form.StartPosition = 'Manual'
# Do not let a changed Windows DPI/font scale expand the outer frame beyond
# the visible desktop. The Shown handler checks the actual screen as well.
$script:Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$script:Form.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$script:Form.Size = [System.Drawing.Size]::new(1200, 760)
$script:Form.MinimumSize = [System.Drawing.Size]::new(700, 480)

$top = New-Object System.Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 51
$top.Padding = [System.Windows.Forms.Padding]::new(9, 9, 9, 6)
$script:Form.Controls.Add($top)

$topLayout = New-Object System.Windows.Forms.FlowLayoutPanel
$topLayout.Dock = 'Fill'
$topLayout.WrapContents = $false
$topLayout.AutoScroll = $true
$top.Controls.Add($topLayout)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = 'Refresh devices'
$refreshButton.AutoSize = $true
$refreshButton.Height = 31
$topLayout.Controls.Add($refreshButton)

$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = 'Export CSV'
$exportButton.AutoSize = $true
$exportButton.Height = 31
$topLayout.Controls.Add($exportButton)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = '  Search:'
$searchLabel.AutoSize = $true
$searchLabel.Margin = [System.Windows.Forms.Padding]::new(6, 7, 3, 3)
$topLayout.Controls.Add($searchLabel)

$script:SearchText = New-Object System.Windows.Forms.TextBox
$script:SearchText.Width = 245
$script:SearchText.Margin = [System.Windows.Forms.Padding]::new(3, 4, 3, 3)
$topLayout.Controls.Add($script:SearchText)

$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Text = 'Find'
$searchButton.AutoSize = $true
$searchButton.Height = 31
$topLayout.Controls.Add($searchButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = 'Clear search'
$clearButton.AutoSize = $true
$clearButton.Height = 31
$topLayout.Controls.Add($clearButton)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Dock = 'Bottom'
$script:StatusLabel.Height = 29
$script:StatusLabel.Padding = [System.Windows.Forms.Padding]::new(10, 6, 0, 0)
$script:StatusLabel.Text = 'Ready.'
$script:Form.Controls.Add($script:StatusLabel)

$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = 'Fill'
$split.Orientation = 'Vertical'
# Do not set SplitterDistance or panel minimums before Windows Forms has
# calculated the final size: the default 150px SplitContainer width can
# cause an exception on some machines when Panel2MinSize is assigned.
$script:Form.Controls.Add($split)
$top.BringToFront()
$script:StatusLabel.BringToFront()

$script:Tree = New-Object System.Windows.Forms.TreeView
$script:Tree.Dock = 'Fill'
$script:Tree.HideSelection = $false
$script:Tree.ShowNodeToolTips = $true
$split.Panel1.Controls.Add($script:Tree)

$detailsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$detailsLayout.Dock = 'Fill'
$detailsLayout.ColumnCount = 1
$detailsLayout.RowCount = 4
$detailsLayout.Padding = [System.Windows.Forms.Padding]::new(10)
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 34)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 37)))
[void]$detailsLayout.RowStyles.Add(([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 49)))
$split.Panel2.Controls.Add($detailsLayout)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$detailsLayout.Controls.Add($tabs, 0, 0)

$easyTab = New-Object System.Windows.Forms.TabPage
$easyTab.Text = 'Easy summary'
$tabs.TabPages.Add($easyTab) | Out-Null

$technicalTab = New-Object System.Windows.Forms.TabPage
$technicalTab.Text = 'Technical details'
$tabs.TabPages.Add($technicalTab) | Out-Null

$script:EasyDetails = New-Object System.Windows.Forms.TextBox
$script:EasyDetails.Multiline = $true
$script:EasyDetails.ReadOnly = $true
$script:EasyDetails.ScrollBars = 'Vertical'
$script:EasyDetails.WordWrap = $true
$script:EasyDetails.Dock = 'Fill'
$script:EasyDetails.Font = [System.Drawing.Font]::new('Segoe UI', 10)
$script:EasyDetails.Text = 'Select a USB controller, hub, port, or connected device on the left.'
$easyTab.Controls.Add($script:EasyDetails)

$script:Details = New-Object System.Windows.Forms.TextBox
$script:Details.Multiline = $true
$script:Details.ReadOnly = $true
$script:Details.ScrollBars = 'Both'
$script:Details.WordWrap = $false
$script:Details.Dock = 'Fill'
$script:Details.Font = [System.Drawing.Font]::new('Consolas', 9)
$script:Details.Text = 'Select a USB controller, hub, port, or connected device on the left.'
$technicalTab.Controls.Add($script:Details)

$script:LabelHelp = New-Object System.Windows.Forms.Label
$script:LabelHelp.AutoSize = $false
$script:LabelHelp.Dock = 'Fill'
$script:LabelHelp.Text = 'Physical port labels: plug a device into a port, select the device, then label its location path.'
$detailsLayout.Controls.Add($script:LabelHelp, 0, 1)

$labelPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$labelPanel.Dock = 'Fill'
$labelPanel.WrapContents = $false
$detailsLayout.Controls.Add($labelPanel, 0, 2)

$script:LabelText = New-Object System.Windows.Forms.TextBox
$script:LabelText.Width = 265
$script:LabelText.Enabled = $false
$labelPanel.Controls.Add($script:LabelText)

$script:SaveLabelButton = New-Object System.Windows.Forms.Button
$script:SaveLabelButton.Text = 'Save label'
$script:SaveLabelButton.AutoSize = $true
$script:SaveLabelButton.Enabled = $false
$labelPanel.Controls.Add($script:SaveLabelButton)

$note = New-Object System.Windows.Forms.Label
$note.Text = 'Easy summary explains speed vs port capability and gives safe physical clues (SS/logo/color/connector) without treating them as proof.'
$note.Dock = 'Fill'
$note.ForeColor = [System.Drawing.Color]::DarkRed
$detailsLayout.Controls.Add($note, 0, 3)

