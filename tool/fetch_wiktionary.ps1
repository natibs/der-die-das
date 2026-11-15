# Downloads the de.wiktionary wikitext for every word in candidates.txt, 50 titles per request.
# Output: tool/wiktionary_cache/batch_NNN.json (re-running skips batches already downloaded).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$words = Get-Content (Join-Path $PSScriptRoot 'candidates.txt') -Encoding UTF8 | Where-Object { $_ }
$out = Join-Path $PSScriptRoot 'wiktionary_cache'
New-Item -ItemType Directory $out -Force | Out-Null
$ua = 'DerDieDas/0.1 (personal German noun app; https://github.com/natibs)'
$total = [Math]::Ceiling($words.Count / 50)
for ($i = 0; $i -lt $total; $i++) {
    $file = Join-Path $out ('batch_{0:D3}.json' -f $i)
    if (Test-Path $file) { continue }
    $titles = ($words[($i * 50)..([Math]::Min($words.Count, ($i + 1) * 50) - 1)]) -join '|'
    $body = @{ action = 'query'; prop = 'revisions'; rvprop = 'content'; rvslots = 'main'; format = 'json'
               formatversion = '2'; redirects = '1'; titles = $titles }
    for ($try = 1; $try -le 4; $try++) {
        try {
            Invoke-WebRequest 'https://de.wiktionary.org/w/api.php' -Method Post -Body $body -UserAgent $ua -OutFile $file -UseBasicParsing
            break
        } catch { Write-Host "batch $i failed ($try): $_"; Start-Sleep -Seconds (5 * $try) }
    }
    Write-Host ("batch {0}/{1}" -f ($i + 1), $total)
    Start-Sleep -Milliseconds 1000
}
"done" | Set-Content (Join-Path $out 'DONE')
