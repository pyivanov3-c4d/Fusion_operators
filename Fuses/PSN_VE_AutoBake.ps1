param(
    [Parameter(Mandatory = $true)][string]$SigDir,
    [Parameter(Mandatory = $true)][string]$Engine,
    [Parameter(Mandatory = $true)][string]$Preset,
    [string]$Node = '',
    [string]$Fuscript = 'C:\Program Files\Blackmagic Design\Fusion 20\fuscript.exe',
    [string]$Refresh = ''
)

# Background baker for PSN_VE_NeuralRender.
# The fuse drops ready input frames into <SigDir>\in and serves whatever is
# already in <SigDir>. This worker batches whatever is pending into one
# VE_CLI call, so the 8 s engine start is paid once per batch instead of
# once per frame.

$inDir = Join-Path $SigDir 'in'
$lock = Join-Path $SigDir 'worker.lock'
$log = Join-Path $SigDir 'worker.log'

function Log($msg) {
    "$(Get-Date -Format 'HH:mm:ss')  $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

Log "worker start: $SigDir"

try {
    $idle = 0
    $lastPoke = [datetime]::MinValue
    while ($true) {
        Start-Sleep -Milliseconds 600

        # keep poking Fusion while we are alive: a single poke gets lost when the
        # viewer is busy (playback) or parked on another frame
        if ($Node -ne '' -and $Refresh -ne '' -and (Test-Path $Fuscript)) {
            if (((Get-Date) - $lastPoke).TotalSeconds -ge 2) {
                $lastPoke = Get-Date
                try { $null = & $Fuscript -l lua $Refresh $Node 2>&1 } catch { }
            }
        }

        $pending = @(Get-ChildItem -Path $inDir -Filter '*.tif' -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-Path (Join-Path $SigDir $_.Name)) })

        if ($pending.Count -eq 0) {
            $idle++
            if ($idle -ge 8) { break }   # ~5 s with nothing to do
            continue
        }
        $idle = 0

        $batch = Join-Path $SigDir ('batch_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $outTmp = Join-Path $SigDir ('out_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $batch -Force | Out-Null
        foreach ($f in $pending) {
            Move-Item -LiteralPath $f.FullName -Destination (Join-Path $batch $f.Name) -Force
        }

        Log ("batch of " + $pending.Count + " -> " + $batch)
        $engineArgs = @('render', $batch, '-o', $outTmp, '--preset', $Preset, '--format', 'tiff', '--bit-depth', '16', '--json', '--quiet')
        $out = & $Engine @engineArgs 2>&1
        Log ("engine: " + ($out -join ' ').Substring(0, [Math]::Min(200, ($out -join ' ').Length)))

        # the engine refuses an output dir that is the parent of the input dir,
        # so results land in a sibling and are promoted here
        if (Test-Path $outTmp) {
            Get-ChildItem -LiteralPath $outTmp -File | Move-Item -Destination $SigDir -Force
            Remove-Item -LiteralPath $outTmp -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $batch -Recurse -Force -ErrorAction SilentlyContinue

        # poke Fusion so the live viewer re-renders the node and shows the result
        Log ("refresh: node='" + $Node + "' script='" + $Refresh + "' fuscript=" + (Test-Path $Fuscript))
        if ($Node -ne '' -and $Refresh -ne '' -and (Test-Path $Fuscript)) {
            $r = & $Fuscript -l lua $Refresh $Node 2>&1
            Log ("refresh out: " + (($r -join ' ')).Trim())
        }
    }
}
finally {
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
    Log 'worker exit'
}
