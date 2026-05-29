<#
================================================================================
 BLM4522 - Proje 5: Veri Temizleme ve ETL
 Otomatik Test Runner (PowerShell)
--------------------------------------------------------------------------------
 sql/ klasorundeki 5 script'i sirayla calistirir, ciktilari log'lar.
 Kullanim: PS> .\run-all.ps1            (varsayilan: localhost, Windows Auth)
           PS> .\run-all.ps1 -Server "MAKINE\INSTANCE"
 Ciktilar: tests\output\run_YYYYMMDD_HHMMSS\*.log
 NOT: SQL Server servisi calismali (yonetici: net start MSSQLSERVER).
================================================================================
#>
[CmdletBinding()]
param([string]$Server = ".")
$ErrorActionPreference = "Stop"

$ScriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
$SqlDir      = Join-Path $ProjectRoot "sql"
$Stamp       = Get-Date -Format "yyyyMMdd_HHmmss"
$OutDir      = Join-Path $ScriptRoot "output\run_$Stamp"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host " BLM4522 - Proje 5: Veri Temizleme ve ETL Testleri" -ForegroundColor Yellow
Write-Host " Server : $Server"
Write-Host " Output : $OutDir"
Write-Host "========================================================" -ForegroundColor Yellow

Write-Step "SQL Server erisim kontrolu"
$ping = & sqlcmd -S $Server -E -C -l 5 -h -1 -W -Q "SELECT @@SERVERNAME" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "SQL Server'a baglanilamadi ($Server)."
    Write-Info "Yonetici PowerShell'de: net start MSSQLSERVER"
    Write-Info "Ayrintili hata: $ping"
    exit 1
}
Write-Ok "SQL Server erisilebilir. ($($ping -join ' '))"

$scripts = @(
    "01_setup_raw_data.sql",
    "02_data_profiling.sql",
    "03_transform_clean.sql",
    "04_load_target.sql",
    "05_quality_report.sql"
)

$results = @()
foreach ($f in $scripts) {
    $path = Join-Path $SqlDir $f
    if (-not (Test-Path $path)) {
        Write-Fail "Eksik: $f"; $results += [pscustomobject]@{ Script = $f; Status = "MISSING" }; continue
    }
    Write-Step "Calistiriliyor: $f"
    $logFile = Join-Path $OutDir ($f -replace "\.sql$", ".log")
    & sqlcmd -S $Server -E -C -I -b -i $path 2>&1 | Tee-Object -FilePath $logFile | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$f"; $results += [pscustomobject]@{ Script = $f; Status = "OK" }
    } else {
        Write-Fail "$f  exit=$LASTEXITCODE (log: $(Split-Path -Leaf $logFile))"
        $results += [pscustomobject]@{ Script = $f; Status = "FAIL" }
        if ($f -eq "01_setup_raw_data.sql") { Write-Fail "Setup basarisiz, kalan atlandi."; break }
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host " OZET" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
$results | Format-Table -AutoSize
$okCount   = ($results | Where-Object Status -eq "OK").Count
$failCount = ($results | Where-Object Status -ne "OK").Count
Write-Host " Basarili : $okCount" -ForegroundColor Green
Write-Host " Basarisiz: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })
Write-Host " Tum log'lar: $OutDir"

$summary = Join-Path $OutDir "SUMMARY.txt"
"BLM4522 - Proje 5 Test Runner"                  | Out-File $summary
"Zaman : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $summary -Append
"Server: $Server"                                | Out-File $summary -Append
$results | Format-Table -AutoSize | Out-String   | Out-File $summary -Append

if ($failCount -gt 0) { exit 1 } else { exit 0 }
