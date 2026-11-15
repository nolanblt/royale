param([string]$Dir)
# Assemble les vignettes (1920 x 1080) et les icones (512 x 512) de la page du
# jeu a partir des captures brutes de Studio (docs/vignettes/brut). Trois
# series de quatre vignettes et trois icones, a comparer : voir LISEZMOI.md.
Add-Type -AssemblyName System.Drawing

$src = Join-Path $Dir "brut"
$W = 1920; $H = 1080

# Une toile : l'image a la hauteur du cadre (la bande choisie), un fond floute
# sur les cotes. Rend aussi l'echelle et le decalage pour placer les cercles.
function New-Canvas([string]$file, [int]$cropTop, [int]$cropHeight, [string]$align = "center") {
    $img = [System.Drawing.Image]::FromFile((Join-Path $src $file))
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $tiny = New-Object System.Drawing.Bitmap 48, 27
    $tg = [System.Drawing.Graphics]::FromImage($tiny)
    $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $tg.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, 48, 27), 0, [int]($img.Height * 0.2), $img.Width, [int]($img.Height * 0.6), [System.Drawing.GraphicsUnit]::Pixel)
    $tg.Dispose()
    $g.DrawImage($tiny, (New-Object System.Drawing.Rectangle -20, -20, ($W + 40), ($H + 40)))
    $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 0, 0, 0))
    $g.FillRectangle($dark, 0, 0, $W, $H)
    $scale = $H / $cropHeight
    $dw = [int]($img.Width * $scale)
    $dx = [int](($W - $dw) / 2)
    if ($align -eq "right") { $dx = $W - $dw }
    # Couleurs ravivees : les captures de Studio sortent ternes (ciel gris,
    # brume), et une miniature se lit d'abord a ses couleurs.
    $s = 1.35; $k = 1.12; $o = -0.03
    $lr = 0.3086 * (1 - $s); $lg = 0.6094 * (1 - $s); $lb2 = 0.0820 * (1 - $s)
    $cm = New-Object System.Drawing.Imaging.ColorMatrix (, [float[][]]@(
            [float[]]@((($lr + $s) * $k), ($lr * $k), ($lr * $k), 0, 0),
            [float[]]@(($lg * $k), (($lg + $s) * $k), ($lg * $k), 0, 0),
            [float[]]@(($lb2 * $k), ($lb2 * $k), (($lb2 + $s) * $k), 0, 0),
            [float[]]@(0, 0, 0, 1, 0),
            [float[]]@($o, $o, $o, 0, 1)))
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetColorMatrix($cm)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $dx, 0, $dw, $H), 0, $cropTop, $img.Width, $cropHeight, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    foreach ($side in @(0, 1)) {
        $x0 = if ($side -eq 0) { $dx } else { $dx + $dw - 160 }
        $rect = New-Object System.Drawing.Rectangle $x0, 0, 160, $H
        $c1 = if ($side -eq 0) { [System.Drawing.Color]::FromArgb(255, 12, 10, 14) } else { [System.Drawing.Color]::FromArgb(0, 12, 10, 14) }
        $c2 = if ($side -eq 0) { [System.Drawing.Color]::FromArgb(0, 12, 10, 14) } else { [System.Drawing.Color]::FromArgb(255, 12, 10, 14) }
        if ($dw -lt $W) {
            $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, 0.0
            $lb.WrapMode = [System.Drawing.Drawing2D.WrapMode]::TileFlipXY
            $g.FillRectangle($lb, $rect)
        }
    }
    $img.Dispose()
    return @{ bmp = $bmp; g = $g; scale = $scale; dx = $dx; top = $cropTop }
}

# Le titre commun a toutes les vignettes (choisi le 15 novembre 2026) :
# Impact, blanc a gros contour noir, un mot cle en jaune ($hot), la meme
# taille partout (reduite seulement si une ligne deborde de sa zone).
# $layout dit ou le poser pour ne cacher ni l'Oeil ni le point d'accroche de
# l'image : "top" ou "bottom" (une ligne, au centre), "left" ou "right" (les
# lignes separees par "|", dans la bande laterale, a partir de $y).
function Add-Head($c, [string]$text, [string]$hot, [string]$layout = "top", [int]$y = 26) {
    $g = $c.g
    $size = 170; $sideW = 700
    $lines = $text.Split("|")
    if ($layout -eq "left" -or $layout -eq "right") { $size = 150; $maxW = $sideW - 60 } else { $maxW = 1640 }
    $family = New-Object System.Drawing.FontFamily "Impact"
    # Mesure : chaque mot en chemin, puis on reduit tant qu'une ligne deborde.
    while ($true) {
        $rows = @(); $widest = 0
        foreach ($line in $lines) {
            $paths = @(); $widths = @(); $total = 0
            # (pas $w : PowerShell ignore la casse, $w ecraserait $W)
            $ws = $line.Split(" ")
            foreach ($word in $ws) {
                $p = New-Object System.Drawing.Drawing2D.GraphicsPath
                $p.AddString($word, $family, 0, $size, (New-Object System.Drawing.Point 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
                $bb = $p.GetBounds()
                $paths += , $p; $widths += $bb.Width; $total += $bb.Width
            }
            $total += $size * 0.22 * ($ws.Count - 1)
            $rows += , @{ words = $ws; paths = $paths; widths = $widths; total = $total }
            if ($total -gt $widest) { $widest = $total }
        }
        if ($widest -le $maxW -or $size -le 80) { break }
        $size -= 6
    }
    $lineH = $size * 1.02
    $blockH = $lineH * $lines.Count
    # Bande sombre derriere le texte, pour qu'il se lise sur un petit ecran.
    switch ($layout) {
        "top" {
            $band = New-Object System.Drawing.Rectangle 0, 0, $W, ($y + $blockH + 90)
            $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $band, ([System.Drawing.Color]::FromArgb(170, 0, 0, 0)), ([System.Drawing.Color]::FromArgb(0, 0, 0, 0)), 90.0
        }
        "bottom" {
            $y = $H - $blockH - 60
            $band = New-Object System.Drawing.Rectangle 0, ($y - 70), $W, ($H - $y + 70)
            $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $band, ([System.Drawing.Color]::FromArgb(0, 0, 0, 0)), ([System.Drawing.Color]::FromArgb(180, 0, 0, 0)), 90.0
        }
        "left" {
            $band = New-Object System.Drawing.Rectangle 0, 0, ($sideW + 120), $H
            $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $band, ([System.Drawing.Color]::FromArgb(170, 0, 0, 0)), ([System.Drawing.Color]::FromArgb(0, 0, 0, 0)), 0.0
        }
        "right" {
            $band = New-Object System.Drawing.Rectangle ($W - $sideW - 120), 0, ($sideW + 120), $H
            $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $band, ([System.Drawing.Color]::FromArgb(0, 0, 0, 0)), ([System.Drawing.Color]::FromArgb(170, 0, 0, 0)), 0.0
        }
    }
    $grad.WrapMode = [System.Drawing.Drawing2D.WrapMode]::TileFlipXY
    $g.FillRectangle($grad, $band)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), ([Math]::Max(16, $size * 0.15))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $hotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 214, 0))
    $ly = $y
    foreach ($row in $rows) {
        switch ($layout) {
            "left" { $x = 30 + ($sideW - 60 - $row.total) / 2 }
            "right" { $x = $W - $sideW + 30 + ($sideW - 60 - $row.total) / 2 }
            default { $x = ($W - $row.total) / 2 }
        }
        for ($i = 0; $i -lt $row.words.Count; $i++) {
            $p = $row.paths[$i]
            $bb = $p.GetBounds()
            $m = New-Object System.Drawing.Drawing2D.Matrix
            $m.Translate([float]($x - $bb.X), [float]$ly)
            $p.Transform($m)
            $g.DrawPath($pen, $p)
            $brush = [System.Drawing.Brushes]::White
            if ($row.words[$i] -eq $hot) { $brush = $hotBrush }
            $g.FillPath($brush, $p)
            $x += $row.widths[$i] + $size * 0.22
        }
        $ly += $lineH
    }
}

# Un cercle rouge autour d'un point de la capture brute (x, y en pixels de la
# capture), comme dans les miniatures « trouve-le ».
function Add-Circle($c, [int]$x, [int]$y, [int]$r) {
    $cx = $c.dx + $x * $c.scale
    $cy = ($y - $c.top) * $c.scale
    $black = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 22
    $redPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 30, 30)), 12
    foreach ($p in @($black, $redPen)) {
        $c.g.DrawEllipse($p, [float]($cx - $r), [float]($cy - $r * 0.9), [float]($r * 2), [float]($r * 1.8))
    }
}

function Save($c, [string]$name) {
    $c.g.Dispose()
    $out = Join-Path $Dir $name
    $null = New-Item -ItemType Directory -Force (Split-Path $out)
    $c.bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $c.bmp.Dispose()
    Write-Output $out
}

# Les douze vignettes, toutes au meme titre (Add-Head), chacun place la ou
# il ne cache ni l'Oeil ni ce qui accroche l'oeil. Le nom du fichier suit le
# titre.
$c = New-Canvas "A-aspire.jpg" 0 1073; Add-Head $c "HIDE FROM|THE EYE" "EYE" "right" 330; Save $c "serie-1/1-hide-from-the-eye.png"
$c = New-Canvas "B-arrache.jpg" 0 1073; Add-Head $c "NO SPOT|IS SAFE" "SAFE" "right" 140; Save $c "serie-1/2-no-spot-is-safe.png"
$c = New-Canvas "C-faisceaux.jpg" 0 1073; Add-Head $c "DON'T GET SEEN" "SEEN" "bottom"; Save $c "serie-1/3-dont-get-seen.png"
$c = New-Canvas "D-escouade.jpg" 0 1073; Add-Head $c "HIDE WITH|FRIENDS" "FRIENDS" "right" 200; Save $c "serie-1/4-hide-with-friends.png"

$c = New-Canvas "2A-grande-roue.jpg" 0 1073; Add-Head $c "HIDE OR GET TAKEN" "TAKEN"; Save $c "serie-2/1-hide-or-get-taken.png"
$c = New-Canvas "2B-lycee.jpg" 0 1073; Add-Head $c "IT SEES|EVERYTHING" "EVERYTHING" "left" 420; Save $c "serie-2/2-it-sees-everything.png"
$c = New-Canvas "2C-wagon.jpg" 0 1073; Add-Head $c "STAY OUT OF SIGHT" "SIGHT"; Save $c "serie-2/3-stay-out-of-sight.png"
$c = New-Canvas "2D-chapiteau.jpg" 0 1073; Add-Head $c "LAST ONE HIDDEN WINS" "WINS"; Save $c "serie-2/4-last-one-hidden-wins.png"

$c = New-Canvas "3D-ligne.jpg" 0 1073; Add-Head $c "WHO GETS|TAKEN?" "TAKEN?" "left" 330; Add-Circle $c 640 850 130; Save $c "serie-3/1-who-gets-taken.png"
$c = New-Canvas "3A-trouve.jpg" 0 820; Add-Head $c "CAN YOU SPOT HIM?" "SPOT"; Add-Circle $c 272 625 95; Save $c "serie-3/2-can-you-spot-him.png"
$c = New-Canvas "3B-dernier.jpg" 0 1073; Add-Head $c "1 LEFT" "1"; Add-Circle $c 628 930 70; Save $c "serie-3/3-one-left.png"
$c = New-Canvas "3C-au-dessus.jpg" 0 1073; Add-Head $c "IT'S RIGHT ABOVE YOU" "ABOVE" "bottom"; Save $c "serie-3/4-right-above-you.png"

# La vignette « logo » : l'Oeil de face (la capture de l'icone) a droite, le
# nom du jeu en grand a gauche, sur le noir de l'Oeil.
$c = New-Canvas "icone.jpg" 0 1073 "right"; Add-Head $c "HIDE|FROM|THE EYE" "EYE" "left" 150; Save $c "logo/1-logo-hide-from-the-eye.png"

# Les icones : un carre de la capture, 512 x 512.
function Save-Icon([string]$file, [int]$cx, [int]$cy, [int]$side, [string]$name) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $src $file))
    $side = [Math]::Min($side, [Math]::Min($img.Width, $img.Height))
    $ix = [Math]::Max(0, [Math]::Min($img.Width - $side, $cx - [int]($side / 2)))
    $iy = [Math]::Max(0, [Math]::Min($img.Height - $side, $cy - [int]($side / 2)))
    $ico = New-Object System.Drawing.Bitmap 512, 512
    $ig = [System.Drawing.Graphics]::FromImage($ico)
    $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $ig.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, 512, 512), $ix, $iy, $side, $side, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
    Save @{ bmp = $ico; g = $ig } $name
}
Save-Icon "icone.jpg" 628 537 1073 "icones/1-oeil.png"
Save-Icon "icone2.jpg" 640 450 860 "icones/2-aspire.png"
Save-Icon "icone3.jpg" 560 560 1073 "icones/3-cache.png"
