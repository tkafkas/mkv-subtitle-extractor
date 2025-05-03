[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InitialFolder,
    [Parameter(Mandatory=$false)]
    [string]$FolderPath,
    [Parameter(Mandatory=$false)]
    [string]$TrackNumber = "-1",
    [Parameter(Mandatory=$false)]
    [string]$Language = ""
)

# Global variables
$script:mkvinfo = "C:\Program Files\MKVToolNix\mkvinfo.exe"
$script:mkvextract = "C:\Program Files\MKVToolNix\mkvextract.exe"
$script:currentFolder = $FolderPath

# Functions
function Get-SubtitleTracks {
    param([string]$FilePath)
    
    $tracks = @()
    Write-Host "`nAnalyzing MKV file structure..." -ForegroundColor Cyan
    
    try {
        $output = & $script:mkvinfo "--ui-language" "en" $FilePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "mkvinfo failed to analyze the file: $FilePath"
            return $tracks
        }
    }
    catch {
        Write-Error "Error running mkvinfo: $_"
        return $tracks
    }

    $trackNumber = $null
    $trackType = $null
    $trackLanguage = $null
    
    foreach($line in $output) {
        if($line -match "\|\s*\+\s*(?:A\s+)?Track\s*$") {
            if($trackType -eq "subtitles" -and $trackNumber -ne $null) {
                $tracks += @{
                    Index = $trackNumber
                    Language = if ([string]::IsNullOrEmpty($trackLanguage)) { "und" } else { $trackLanguage }
                    Type = $trackType
                }
            }
            $trackNumber = $null
            $trackType = $null
            $trackLanguage = $null
        }
        
        if($line -match "\|\s*\+?\s*Track number:\s*(\d+)") {
            $trackNumber = [int]$matches[1] - 1
        }
        
        if($line -match "\|\s*\+?\s*Track type:\s*(\w+)") {
            $trackType = $matches[1].ToLower()
            if($trackType -match "subt?itles?|subs?|text|ssa|ass|vobsub|srt|idx|pgs|dvd") {
                $trackType = "subtitles"
            }
        }
        
        if($line -match "\|\s*\+?\s*Language:\s*(\w+)") {
            $trackLanguage = $matches[1].ToLower()
            if($trackLanguage -eq "und" -or $trackLanguage -eq "unknown") {
                $trackLanguage = "und"
            }
        }
    }
    
    if($trackType -eq "subtitles" -and $trackNumber -ne $null) {
        $tracks += @{
            Index = $trackNumber
            Language = if ([string]::IsNullOrEmpty($trackLanguage)) { "und" } else { $trackLanguage }
            Type = $trackType
        }
    }
    
    Write-Host "`nFound $($tracks.Count) subtitle track$(if($tracks.Count -ne 1){"s"}):" -ForegroundColor Cyan
    for($i = 0; $i -lt $tracks.Count; $i++) {
        $track = $tracks[$i]
        Write-Host "  $($i + 1). Track $($track.Index + 1): $($track.Language)" -ForegroundColor White
    }
    
    return $tracks
}

function Process-MkvFile {
    param(
        [string]$FilePath,
        [string]$TrackNumber = "-1",
        [string]$Language = ""
    )

    $tracks = Get-SubtitleTracks -FilePath $FilePath
    if($tracks.Count -eq 0) {
        Write-Host "No subtitle tracks found."
        return
    }

    if($TrackNumber -ne "-1") {
        try {
            [int]$selectedTrack = [int]$TrackNumber
            if($selectedTrack -lt 1 -or $selectedTrack -gt $tracks.Count) {
                Write-Host "`nTrack $selectedTrack not available in this file" -ForegroundColor Yellow
                return
            }
            $tracks = @($tracks[$selectedTrack - 1])
        }
        catch {
            Write-Error "Invalid track number"
            return
        }
    }
    elseif($Language) {
        $tracks = $tracks | Where-Object { $_.Language -eq $Language.ToLower() }
        if($tracks.Count -eq 0) {
            Write-Host "No tracks found with language: $Language" -ForegroundColor Yellow
            return
        }
    }

    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $outputPath = [System.IO.Path]::GetDirectoryName($FilePath)

    foreach($track in $tracks) {
        # Add language code to filename if multiple tracks are being extracted (TrackNumber = -1 and no specific language)
        $outputFile = if ($TrackNumber -eq "-1" -and -not $Language) {
            Join-Path $outputPath "$baseFileName.$($track.Language).srt"
        } else {
            Join-Path $outputPath "$baseFileName.srt"
        }
        Write-Host "`nExtracting track $($track.Index + 1) ($($track.Language)) to: $([System.IO.Path]::GetFileName($outputFile))" -ForegroundColor Green
        
        try {
            & $script:mkvextract "tracks" $FilePath "$($track.Index):$outputFile" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to extract track $($track.Index + 1)"
                continue
            }
            Write-Host "Extraction successful" -ForegroundColor Green
        }
        catch {
            Write-Error "Error extracting track: $_"
        }
    }
}

function Show-MainMenu {
    Clear-Host
    if ($script:currentFolder) {
        Write-Host "`nCurrent folder: $($script:currentFolder)"
    }
    else {
        Write-Host "`nNo folder selected" -ForegroundColor Yellow
    }
    
    Write-Host "`nSelect subtitle language:`n"
    Write-Host "1. Greek (gre)"
    Write-Host "2. English (eng)"
    Write-Host "3. Extract by track number"
    Write-Host "4. Extract all available tracks"
    Write-Host "5. Change folder"
    Write-Host "Q. Quit`n"
}

function Select-Folder {
    $newFolder = Read-Host "Enter folder path (or press Enter to browse)"
    if([string]::IsNullOrWhiteSpace($newFolder)) {
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select folder containing MKV files"
        if($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $newFolder = $folderBrowser.SelectedPath
        }
    }
    
    if(![string]::IsNullOrWhiteSpace($newFolder)) {
        if(Test-Path -LiteralPath $newFolder) {
            $script:currentFolder = $newFolder
            Write-Host "`nFolder changed to: $newFolder" -ForegroundColor Green
        }
        else {
            Write-Host "`nFolder not found: $newFolder" -ForegroundColor Red
        }
    }
}

function Handle-Menu {
    $keepRunning = $true

    while ($keepRunning) {
        Clear-Host
        Show-MainMenu
        $choice = Read-Host "Enter your choice (1-5 or Q)"

        switch -Regex ($choice) {
            "^[Qq]$" {
                $keepRunning = $false
                break
            }
            "^1$" {
                Clear-Host
                Write-Host "Processing Greek subtitles..." -ForegroundColor Cyan
                $keepRunning = Process-Folder -Language "gre"
            }
            "^2$" {
                Clear-Host
                Write-Host "Processing English subtitles..." -ForegroundColor Cyan
                $keepRunning = Process-Folder -Language "eng"
            }
            "^3$" {
                Clear-Host
                $trackNum = Read-Host "Enter track number"
                Write-Host "Processing track $trackNum..." -ForegroundColor Cyan
                $keepRunning = Process-Folder -TrackNumber $trackNum
            }
            "^4$" {
                Clear-Host
                Write-Host "Processing all available subtitle tracks..." -ForegroundColor Cyan
                $keepRunning = Process-Folder -TrackNumber "-1"
            }
            "^5$" {
                Clear-Host
                Select-Folder
                Start-Sleep -Milliseconds 500
            }
            default {
                Write-Host "`nInvalid choice. Please try again." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Process-Folder {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TrackNumber = "-1",
        [Parameter(Mandatory=$false)]
        [string]$Language = "",
        [Parameter(Mandatory=$false)]
        [string]$FolderPath
    )

    $folderToProcess = if($FolderPath) { $FolderPath } else { $script:currentFolder }
    
    if(-not $folderToProcess) {
        Write-Host "`nNo folder selected. Please select a folder first." -ForegroundColor Yellow
        return
    }

    if(-not (Test-Path -LiteralPath $folderToProcess)) {
        Write-Host "`nFolder not found: $folderToProcess" -ForegroundColor Yellow
        return
    }

    $mkvFiles = Get-ChildItem -LiteralPath $folderToProcess -Filter "*.mkv"
    if($mkvFiles.Count -eq 0) {
        Write-Host "`nNo MKV files found in the current folder." -ForegroundColor Yellow
        return
    }

    Write-Host "`nFound $($mkvFiles.Count) MKV files to process..."
    
    $processedCount = 0
    foreach($mkvFile in $mkvFiles) {
        $processedCount++
        Write-Host "`nProcessing file $processedCount of $($mkvFiles.Count): $($mkvFile.Name)" -ForegroundColor Cyan
        Process-MkvFile -FilePath $mkvFile.FullName -TrackNumber $TrackNumber -Language $Language
    }
    
    if ($processedCount -gt 0) {
        Write-Host "`nProcessing complete!" -ForegroundColor Green
        Write-Host "Processed $processedCount file$(if($processedCount -ne 1){'s'})`n"
        
        Write-Host "Do you want to process more files? (Y/N)" -ForegroundColor Cyan
        $response = Read-Host
        
        $continue = $response.Trim().ToUpper() -eq "Y"
        
        if ($continue) {
            Clear-Host
            Write-Host "Returning to menu..." -ForegroundColor Cyan
            Start-Sleep -Milliseconds 500
        }
        else {
            Clear-Host
        }
        
        return $continue
    }
    return $true  # Return true if no files processed to keep menu active
}

# Verify tools are installed at startup
if(-not (Test-Path $script:mkvinfo)) {
    Write-Error "mkvinfo not found at: $script:mkvinfo"
    exit 1
}
if(-not (Test-Path $script:mkvextract)) {
    Write-Error "mkvextract not found at: $script:mkvextract"
    exit 1
}

# Set initial folder if provided
if($FolderPath) {
    if(Test-Path -LiteralPath $FolderPath) {
        $script:currentFolder = $FolderPath
    }
    else {
        Write-Error "Folder not found: $FolderPath"
        exit 1
    }
}
elseif($InitialFolder) {
    if(Test-Path -LiteralPath $InitialFolder) {
        $script:currentFolder = $InitialFolder
    }
    else {
        Write-Error "Specified folder not found: $InitialFolder"
        exit 1
    }
}

# Handle command-line mode
if($FolderPath -and ($Language -or $TrackNumber -ne "-1")) {
    Process-Folder -Language $Language -TrackNumber $TrackNumber
    exit 0
}

# Main program
Clear-Host
Write-Host "Welcome to MKV Subtitle Extractor" -ForegroundColor Green
Start-Sleep -Milliseconds 500
Clear-Host

# Prompt for initial folder selection if no folder is set
if (-not $script:currentFolder) {
    Write-Host "Please select a folder containing MKV files" -ForegroundColor Cyan
    Select-Folder
}

# Start menu loop
Handle-Menu

# Show exit message
Clear-Host
Write-Host "`nThank you for using the subtitle extractor!" -ForegroundColor Green
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")