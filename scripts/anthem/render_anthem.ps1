# render_anthem.ps1
# Renders Star-Spangled Banner MIDI to WAV using FluidSynth.
# Usage: pwsh scripts/anthem/render_anthem.ps1
# Requires: fluidsynth on PATH, star_spangled_banner.mid, and a .sf2 soundfont
#           placed in the same directory as this script.

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$MidiFile   = Join-Path $ScriptDir "star_spangled_banner.mid"
$RenderedWav = Join-Path $ScriptDir "anthem_rendered.wav"
$OutputWav  = "assets\audio\anthem.wav"

# Resolve SF2: prefer GeneralUser GS, fall back to MuseScore General
$Sf2File = Join-Path $ScriptDir "GeneralUser_GS.sf2"
if (-not (Test-Path $Sf2File)) {
    $Sf2File = Join-Path $ScriptDir "MuseScore_General.sf2"
    if (-not (Test-Path $Sf2File)) {
        Write-Error "No SF2 soundfont found in $ScriptDir. Place GeneralUser_GS.sf2 or MuseScore_General.sf2 there."
        exit 1
    }
    Write-Host "Using MuseScore General SF2 fallback."
}

if (-not (Test-Path $MidiFile)) {
    Write-Error "MIDI source not found: $MidiFile"
    exit 1
}

Write-Host "Rendering anthem..."
Write-Host "  SF2:  $Sf2File"
Write-Host "  MIDI: $MidiFile"
Write-Host "  Out:  $RenderedWav"

fluidsynth -ni -F $RenderedWav -r 44100 -g 0.8 $Sf2File $MidiFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "FluidSynth exited with code $LASTEXITCODE"
    exit 1
}

if (-not (Test-Path $RenderedWav)) {
    Write-Error "FluidSynth did not produce output at $RenderedWav"
    exit 1
}

$Size = (Get-Item $RenderedWav).Length
Write-Host "Rendered: $([math]::Round($Size / 1MB, 1)) MB"

Copy-Item -Force $RenderedWav $OutputWav
Write-Host "Copied to $OutputWav"
Write-Host "SUCCESS: anthem.wav ready. Play it on desktop to verify before running the next wave."
