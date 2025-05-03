# MKV Subtitle Extractor

A PowerShell-based utility for extracting subtitle tracks from MKV (Matroska) video files. The tool provides both an interactive menu interface and command-line options for batch processing.

## Features

- Extract subtitles from single or multiple MKV files
- Interactive menu-driven interface
- Command-line support for automation
- Multiple extraction modes:
  - Extract specific language tracks (Greek/English)
  - Extract by track number
  - Extract all available subtitle tracks
- Automatic subtitle track detection and language identification
- Support for folder browsing or direct path input
- Preserves original subtitle format (converts to SRT)

## Requirements

- Windows operating system
- MKVToolNix (automatically installed via winget)
- PowerShell

## Installation

1. Install MKVToolNix using the provided requirements.txt:
```cmd
winget install --id=MoritzBunkus.MKVToolNix  -e
```

2. Download the following files:
   - `extract_subs.ps1` (Main PowerShell script)
   - `extract_subs.bat` (Batch launcher)
   - `requirements.txt` (Dependencies)

## Usage

### Interactive Mode

1. Double-click `extract_subs.bat` to launch the program
2. Select or browse to the folder containing your MKV files
3. Choose from the menu options:
   - Extract Greek subtitles
   - Extract English subtitles
   - Extract by track number
   - Extract all available tracks
   - Change folder

### Command-Line Mode

The script supports command-line parameters for automation:

```powershell
.\extract_subs.ps1 [-InitialFolder <path>] [-FolderPath <path>] [-TrackNumber <number>] [-Language <code>]
```

Parameters:
- `-InitialFolder`: Sets the starting folder for interactive mode
- `-FolderPath`: Specifies the folder to process (enables command-line mode)
- `-TrackNumber`: Extract specific track number (-1 for all tracks)
- `-Language`: Extract tracks of specific language (e.g., "eng" or "gre")

Examples:

```powershell
# Extract all English subtitles from a specific folder
.\extract_subs.ps1 -FolderPath "C:\Movies" -Language "eng"

# Extract track number 2 from all MKV files in a folder
.\extract_subs.ps1 -FolderPath "C:\Movies" -TrackNumber 2

# Extract all subtitle tracks from a folder
.\extract_subs.ps1 -FolderPath "C:\Movies" -TrackNumber -1
```

## Output

- Extracted subtitles are saved in the same folder as the source MKV file
- Files are named using the pattern: `[original_name].[language].srt`
- For single track extraction, the language code is omitted from the filename

## Notes

- The tool requires MKVToolNix to be installed in the default location
- If multiple subtitle tracks are extracted, the language code is added to the filename
- Unknown language tracks are marked as "und"
- The script automatically creates output files in SRT format