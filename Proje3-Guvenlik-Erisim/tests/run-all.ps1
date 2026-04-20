<#
================================================================================
 Proje 3 - Guvenlik ve Erisim Kontrolu
 Otomatik Test Runner (PowerShell)
--------------------------------------------------------------------------------
 Amac  : sql/ klasorundeki 9 script'i sirayla calistirmak, ciktilari
         log'lamak, her asamada basari/hata kontrolu yapmak.
 Kullanim:
     PS> .\run-all.ps1                    # varsayilan: localhost, Windows Auth
     PS> .\run-all.ps1 -Server "MAKINE"   # farkli sunucu
     PS> .\run-all.ps1 -OnlyTest          # sadece 09_test_permissions.sql
 Ciktilar: tests\output\run_YYYYMMDD_HHMMSS\*.log
================================================================================
#>

[CmdletBinding()]
param(
    [string]$Server = ".",
    [switch]$OnlyTest,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

# --- Yollar ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
$SqlDir = Join-Path $ProjectRoot "sql"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutDir = Join-Path $ScriptRoot "output\run_$Stamp"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# --- Renkli yazdirma yardimcilari ---
function Write-Step($msg)    { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Fail($msg)    { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Info($msg)    { Write-Host "       $msg" -ForegroundColor DarkGray }

# --- Baslangic banner ---
Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host " BLM4522 - Proje 3: Guvenlik ve Erisim Testleri" -ForegroundColor Yellow
Write-Host " Server : $Server"
Write-Host " Output : $OutDir"
Write-Host "========================================================" -ForegroundColor Yellow

# --- SQL Server erisim kontrolu ---
Write-Step "SQL Server erisim kontrolu"
$ping = & sqlcmd -S $Server -E -C -l 5 -Q "SELECT @@SERVERNAME AS srv, SERVERPROPERTY('ProductVersion') AS ver" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "SQL Server'a baglanilamadi ($Server)."
    Write-Info "Servisi baslatmak icin yonetici olarak: net start MSSQLSERVER"
    Write-Info "Ayrintili hata: $ping"
    exit 1
}
Write-Ok "SQL Server erisilebilir."
Write-Info ($ping -join " | ")

# --- Calistirilacak script listesi ---
$allScripts = @(
    "01_setup_database.sql",
    "02_auth_modes.sql",
    "03_roles_and_permissions.sql",
    "04_tde_encryption.sql",
    "05_sql_injection_demo.sql",
    "06_audit_setup.sql",
    "07_audit_query.sql",
    "08_row_level_security.sql",
    "09_test_permissions.sql"
)

$scripts = if ($OnlyTest) { @("09_test_permissions.sql") } else { $allScripts }

# --- Calistir ---
$results = @()
foreach ($f in $scripts) {
    $path = Join-Path $SqlDir $f
    if (-not (Test-Path $path)) {
        Write-Fail "Eksik: $f"
        $results += [pscustomobject]@{ Script = $f; Status = "MISSING"; Log = "" }
        continue
    }

    Write-Step "Calistiriliyor: $f"
    $logFile = Join-Path $OutDir ($f -replace "\.sql$", ".log")

    & sqlcmd -S $Server -E -C -I -b -i $path 2>&1 | Tee-Object -FilePath $logFile | Out-Null
    $exit = $LASTEXITCODE

    if ($exit -eq 0) {
        Write-Ok "$f (log: $(Split-Path -Leaf $logFile))"
        $results += [pscustomobject]@{ Script = $f; Status = "OK"; Log = $logFile }
    } else {
        Write-Fail "$f  exit=$exit  (log: $(Split-Path -Leaf $logFile))"
        $results += [pscustomobject]@{ Script = $f; Status = "FAIL"; Log = $logFile }
        # 01 basarisiz olursa digerlerini calistirmak anlamsiz
        if ($f -eq "01_setup_database.sql") {
            Write-Fail "Setup basarisiz. Kalan script'ler atlanacak."
            break
        }
    }
}

# --- Ozet ---
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
Write-Host ""
Write-Host " Tum log'lar: $OutDir"

# --- Ozeti dosyaya yaz ---
$summary = Join-Path $OutDir "SUMMARY.txt"
"BLM4522 - Proje 3 Test Runner"   | Out-File $summary
"Zaman : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $summary -Append
"Server: $Server"                 | Out-File $summary -Append
""                                | Out-File $summary -Append
$results | Format-Table -AutoSize | Out-String | Out-File $summary -Append

if ($failCount -gt 0) { exit 1 } else { exit 0 }
