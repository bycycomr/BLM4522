<#
================================================================================
 BLM4522 - Proje 1: Performans Optimizasyonu ve Izleme
 Otomatik Test Runner (PowerShell)
--------------------------------------------------------------------------------
 Amac : sql/ klasorundeki 5 script'i sirayla calistirir, ciktilari log'lar,
        her asamada basari/hata kontrolu yapar.
 Kullanim:
     PS> .\run-all.ps1                  # varsayilan: localhost (.), Windows Auth
     PS> .\run-all.ps1 -Server "MAKINE\INSTANCE"
 Ciktilar: tests\output\run_YYYYMMDD_HHMMSS\*.log
 NOT: Once SQL Server servisi calismali. Yonetici PowerShell'de:
        net start MSSQLSERVER
================================================================================
#>
[CmdletBinding()]
param(
    [string]$Server = "."
)

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
Write-Host " BLM4522 - Proje 1: Performans Optimizasyonu Testleri" -ForegroundColor Yellow
Write-Host " Server : $Server"
Write-Host " Output : $OutDir"
Write-Host "========================================================" -ForegroundColor Yellow

# --- SQL Server erisim kontrolu ---
Write-Step "SQL Server erisim kontrolu"
$ping = & sqlcmd -S $Server -E -C -l 5 -Q "SELECT @@SERVERNAME AS srv, SERVERPROPERTY('ProductVersion') AS ver" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "SQL Server'a baglanilamadi ($Server)."
    Write-Info "Yonetici PowerShell'de servisi baslatin: net start MSSQLSERVER"
    Write-Info "Ayrintili hata: $ping"
    exit 1
}
Write-Ok "SQL Server erisilebilir."
Write-Info ($ping -join " | ")

# --- Calistirilacak script listesi (sirali) ---
$scripts = @(
    "01_setup_database.sql",
    "02_izleme_ve_analiz.sql",
    "03_indeksleme.sql",
    "04_disk_ve_yogunluk.sql",
    "05_roller_ve_erisim.sql"
)

$results = @()
foreach ($f in $scripts) {
    $path = Join-Path $SqlDir $f
    if (-not (Test-Path $path)) {
        Write-Fail "Eksik: $f"
        $results += [pscustomobject]@{ Script = $f; Status = "MISSING" }
        continue
    }

    Write-Step "Calistiriliyor: $f"
    $logFile = Join-Path $OutDir ($f -replace "\.sql$", ".log")

    & sqlcmd -S $Server -E -C -I -b -i $path 2>&1 | Tee-Object -FilePath $logFile | Out-Null
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        Write-Ok "$f (log: $(Split-Path -Leaf $logFile))"
        $results += [pscustomobject]@{ Script = $f; Status = "OK" }
    } else {
        Write-Fail "$f  exit=$exit  (log: $(Split-Path -Leaf $logFile))"
        $results += [pscustomobject]@{ Script = $f; Status = "FAIL" }
        if ($f -eq "01_setup_database.sql") {
            Write-Fail "Setup basarisiz. Kalan script'ler atlanacak."
            break
        }
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host " OZET" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
$results | Format-Table -AutoSize

$okCount   = ($results | Where-Object Status -eq "OK").Count
$failCount = ($results | Where-Object Status -ne "OK").Count
Write-Host ""
Write-Host " Basarili : $okCount" -ForegroundColor Green
Write-Host " Basarisiz: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })
Write-Host " Tum log'lar: $OutDir"

$summary = Join-Path $OutDir "SUMMARY.txt"
"BLM4522 - Proje 1 Test Runner"                  | Out-File $summary
"Zaman : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $summary -Append
"Server: $Server"                                | Out-File $summary -Append
""                                               | Out-File $summary -Append
$results | Format-Table -AutoSize | Out-String   | Out-File $summary -Append

if ($failCount -gt 0) { exit 1 } else { exit 0 }
