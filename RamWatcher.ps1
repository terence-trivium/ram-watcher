# Claude Code / Chrome / Docker RAM Watcher
# Petit widget de bureau toujours au premier plan : RAM, CPU, qui bouffe quoi,
# boutons pour tuer un process en urgence, et logs exportables pour debug.
# A lancer via RamWatcher.vbs (evite la fenetre de console PowerShell).
# Deplacer : cliquer-glisser la zone de stats en haut.
# Fermer : clic droit > Quitter.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logPath = Join-Path $PSScriptRoot "ramwatcher.log.csv"
$logHeader = "Timestamp,RAM_used_MB,RAM_total_MB,RAM_pct,CPU_pct,Chrome_MB,ClaudeNode_MB,DockerWSL_MB,Top1,Top1_MB,Top2,Top2_MB,Top3,Top3_MB,Top4,Top4_MB,Top5,Top5_MB"

$form = New-Object System.Windows.Forms.Form
$form.Text = "RAM Watcher"
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
$form.Opacity = 0.94
$form.Size = New-Object System.Drawing.Size(340, 470)
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($screen.Width - 360), 20)

$font = New-Object System.Drawing.Font("Consolas", 9)
$statsLabel = New-Object System.Windows.Forms.Label
$statsLabel.Font = $font
$statsLabel.ForeColor = [System.Drawing.Color]::White
$statsLabel.BackColor = [System.Drawing.Color]::Transparent
$statsLabel.AutoSize = $false
$statsLabel.Dock = 'Fill'
$statsLabel.Padding = New-Object System.Windows.Forms.Padding(10)
$statsLabel.Text = "Chargement..."

# --- Panneau boutons (en bas) ---
$bottomPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$bottomPanel.Dock = 'Bottom'
$bottomPanel.Height = 230
$bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(15,15,15)
$bottomPanel.FlowDirection = 'TopDown'
$bottomPanel.WrapContents = $false
$bottomPanel.Padding = New-Object System.Windows.Forms.Padding(8)

function New-KillButton($text, $color) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Width = 300
    $btn.Height = 28
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.BackColor = $color
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    return $btn
}

$btnKillTop    = New-KillButton "Tuer le plus gros process" ([System.Drawing.Color]::FromArgb(150,30,30))
$btnKillChrome = New-KillButton "Tuer Chrome"                ([System.Drawing.Color]::FromArgb(120,60,20))
$btnKillNode   = New-KillButton "Tuer Claude/Node"           ([System.Drawing.Color]::FromArgb(120,60,20))
$btnKillDocker = New-KillButton "Tuer Docker/WSL"            ([System.Drawing.Color]::FromArgb(120,60,20))
$btnLogs       = New-KillButton "Ouvrir les logs"            ([System.Drawing.Color]::FromArgb(40,40,40))

$customPanel = New-Object System.Windows.Forms.Panel
$customPanel.Width = 300
$customPanel.Height = 28
$txtKill = New-Object System.Windows.Forms.TextBox
$txtKill.Width = 200
$txtKill.Location = New-Object System.Drawing.Point(0, 3)
$btnKillCustom = New-Object System.Windows.Forms.Button
$btnKillCustom.Text = "Tuer"
$btnKillCustom.Width = 90
$btnKillCustom.Height = 25
$btnKillCustom.Location = New-Object System.Drawing.Point(206, 0)
$btnKillCustom.FlatStyle = 'Flat'
$btnKillCustom.ForeColor = [System.Drawing.Color]::White
$btnKillCustom.BackColor = [System.Drawing.Color]::FromArgb(150,30,30)
$customPanel.Controls.Add($txtKill)
$customPanel.Controls.Add($btnKillCustom)

$bottomPanel.Controls.Add($btnKillTop)
$bottomPanel.Controls.Add($btnKillChrome)
$bottomPanel.Controls.Add($btnKillNode)
$bottomPanel.Controls.Add($btnKillDocker)
$bottomPanel.Controls.Add($customPanel)
$bottomPanel.Controls.Add($btnLogs)

# Ordre d'ajout important pour le docking : Bottom d'abord, Fill en dernier
$form.Controls.Add($bottomPanel)
$form.Controls.Add($statsLabel)

# --- Deplacement au clic-glisser (uniquement sur la zone de stats) ---
$script:dragging = $false
$script:dragStart = New-Object System.Drawing.Point 0,0

$downHandler = {
    $script:dragging = $true
    $script:dragStart = New-Object System.Drawing.Point($_.X, $_.Y)
}
$moveHandler = {
    if ($script:dragging) {
        $p = $this.PointToScreen($_.Location)
        $form.Location = New-Object System.Drawing.Point(($p.X - $script:dragStart.X), ($p.Y - $script:dragStart.Y))
    }
}
$upHandler = { $script:dragging = $false }

$form.Add_MouseDown($downHandler)
$form.Add_MouseMove($moveHandler)
$form.Add_MouseUp($upHandler)
$statsLabel.Add_MouseDown($downHandler)
$statsLabel.Add_MouseMove($moveHandler)
$statsLabel.Add_MouseUp($upHandler)

# --- Clic droit pour quitter ---
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$quit = $menu.Items.Add("Quitter")
$quit.Add_Click({ $form.Close() })
$form.ContextMenuStrip = $menu
$statsLabel.ContextMenuStrip = $menu

function Get-Bar {
    param($pct, $width = 20)
    $filled = [Math]::Round(($pct / 100) * $width)
    if ($filled -lt 0) { $filled = 0 }
    if ($filled -gt $width) { $filled = $width }
    return ("#" * $filled) + ("." * ($width - $filled))
}

function Get-AllProcs {
    # Exclut le process du widget lui-meme (powershell/pwsh) pour ne pas se compter
    Get-Process | Where-Object { $_.ProcessName -notin @('powershell','pwsh') } |
        Group-Object ProcessName | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                MB   = [Math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB)
            }
        }
}

function Confirm-Kill($msg) {
    $r = [System.Windows.Forms.MessageBox]::Show($msg, "Confirmer", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Kill-Names($names) {
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Groupes de process a surveiller en priorite (Chrome, Claude Code/node, Docker+WSL)
$watchedGroups = [ordered]@{
    "Chrome"      = @("chrome")
    "Claude/Node" = @("node", "Claude")
    "Docker/WSL"  = @("Docker Desktop", "com.docker.backend", "com.docker.build", "vmmem", "vmmemWSL", "wslhost", "wsl")
}

# --- Boutons kill ---
$btnKillTop.Add_Click({
    $top = Get-AllProcs | Sort-Object MB -Descending | Select-Object -First 1
    if ($top -and (Confirm-Kill "Tuer $($top.Name) ($($top.MB) Mo) ?")) {
        Kill-Names @($top.Name)
    }
})
$btnKillChrome.Add_Click({
    if (Confirm-Kill "Tuer tous les process Chrome ?") { Kill-Names $watchedGroups["Chrome"] }
})
$btnKillNode.Add_Click({
    if (Confirm-Kill "Tuer tous les process Claude/Node ? (perte de contexte en cours possible)") { Kill-Names $watchedGroups["Claude/Node"] }
})
$btnKillDocker.Add_Click({
    if (Confirm-Kill "Tuer Docker Desktop / WSL ?") { Kill-Names $watchedGroups["Docker/WSL"] }
})
$btnKillCustom.Add_Click({
    $name = $txtKill.Text.Trim()
    if ($name -and (Confirm-Kill "Tuer tous les process '$name' ?")) { Kill-Names @($name) }
})
$btnLogs.Add_Click({
    if (Test-Path $logPath) {
        Start-Process explorer.exe "/select,`"$logPath`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Pas encore de logs (attends quelques secondes).", "Info")
    }
})

function Write-Log($usedMB, $totalMB, $pctRAM, $cpuLoad, $groupSums, $top5) {
    try {
        if ((Test-Path $logPath) -and ((Get-Item $logPath).Length -gt 5MB)) {
            $old = Join-Path $PSScriptRoot "ramwatcher.log.old.csv"
            Move-Item -Path $logPath -Destination $old -Force
        }
        if (-not (Test-Path $logPath)) {
            $logHeader | Out-File -FilePath $logPath -Encoding utf8
        }
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $vals = @($ts, $usedMB, $totalMB, $pctRAM, [Math]::Round($cpuLoad), $groupSums["Chrome"], $groupSums["Claude/Node"], $groupSums["Docker/WSL"])
        for ($i = 0; $i -lt 5; $i++) {
            if ($i -lt $top5.Count) { $vals += $top5[$i].Name; $vals += $top5[$i].MB } else { $vals += ""; $vals += "" }
        }
        ($vals -join ",") | Out-File -FilePath $logPath -Append -Encoding utf8
    } catch { }
}

$script:tickCount = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMB = [Math]::Round($os.TotalVisibleMemorySize / 1024)
        $freeMB  = [Math]::Round($os.FreePhysicalMemory / 1024)
        $usedMB  = $totalMB - $freeMB
        $pctRAM  = [Math]::Round(($usedMB / $totalMB) * 100)

        $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($null -eq $cpuLoad) { $cpuLoad = 0 }

        $allProcs = Get-AllProcs

        $lines = @()
        $lines += "  RAM   $usedMB / $totalMB Mo  ($pctRAM%)"
        $lines += "  [$(Get-Bar $pctRAM)]"
        $lines += "  Libre : $freeMB Mo"
        $lines += ""
        $lines += "  CPU   $([Math]::Round($cpuLoad))%"
        $lines += "  [$(Get-Bar $cpuLoad)]"
        $lines += ""
        $lines += "  -- Suspects --"
        $groupSums = @{}
        foreach ($grp in $watchedGroups.GetEnumerator()) {
            $sum = ($allProcs | Where-Object { $grp.Value -contains $_.Name } | Measure-Object MB -Sum).Sum
            if (-not $sum) { $sum = 0 }
            $groupSums[$grp.Key] = $sum
            $lines += ("  {0,-12} {1,6} Mo" -f $grp.Key, $sum)
        }
        $lines += ""
        $lines += "  -- Top 5 global --"
        $top5 = @($allProcs | Sort-Object MB -Descending | Select-Object -First 5)
        foreach ($p in $top5) {
            $lines += ("  {0,-16} {1,6} Mo" -f $p.Name, $p.MB)
        }

        $statsLabel.Text = ($lines -join "`r`n")

        if ($pctRAM -ge 90) {
            $form.BackColor = [System.Drawing.Color]::FromArgb(60,20,20)
        } elseif ($pctRAM -ge 75) {
            $form.BackColor = [System.Drawing.Color]::FromArgb(50,40,15)
        } else {
            $form.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
        }

        $script:tickCount++
        if ($script:tickCount % 5 -eq 0) {
            Write-Log $usedMB $totalMB $pctRAM $cpuLoad $groupSums $top5
        }
    } catch {
        $statsLabel.Text = "Erreur : $($_.Exception.Message)"
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run($form)
