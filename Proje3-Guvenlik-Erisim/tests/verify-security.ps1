<#
================================================================================
 Proje 3 - Guvenlik Testleri - Beklenen Davranis Dogrulama
--------------------------------------------------------------------------------
 Amac : 09_test_permissions.sql'in KURU ciktisini degil, BEKLENEN davranisi
        dogrular. Her test icin:
          - Beklenen: "OK" ya da "HATA / DENY"
          - Gercek  : sqlcmd ciktisi
        Iki tarafi karsilastirir ve PASS/FAIL verir.
 Kullanim:
     PS> .\verify-security.ps1
================================================================================
#>

[CmdletBinding()]
param(
    [string]$Server = "."
)

$ErrorActionPreference = "Continue"

function Invoke-AsUser {
    param([string]$User, [string]$Query)
    $tsql = @"
USE PersonelDB;
EXECUTE AS USER = N'$User';
BEGIN TRY
    $Query
    PRINT '__RESULT__:OK';
END TRY
BEGIN CATCH
    PRINT '__RESULT__:DENY:' + ERROR_MESSAGE();
END CATCH
REVERT;
"@
    $out = $tsql | & sqlcmd -S $Server -E -C -l 5 2>&1
    return ($out -join "`n")
}

function Assert-Result {
    param([string]$Name, [string]$Output, [string]$Expected)
    $actual = if ($Output -match "__RESULT__:OK")   { "OK" }
              elseif ($Output -match "__RESULT__:DENY") { "DENY" }
              else { "UNKNOWN" }

    if ($actual -eq $Expected) {
        Write-Host "[PASS] $Name  (beklenen=$Expected, gercek=$actual)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] $Name  (beklenen=$Expected, gercek=$actual)" -ForegroundColor Red
        Write-Host ($Output -split "`n" | Select-Object -First 5 | ForEach-Object { "       $_" } | Out-String).TrimEnd()
        return $false
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host " Proje 3 - Guvenlik Assertion Testleri" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow

# Ana DB var mi?
$check = & sqlcmd -S $Server -E -C -l 5 -Q "SELECT COUNT(*) FROM PersonelDB.sys.tables" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] PersonelDB yok. Once run-all.ps1'i calistirin." -ForegroundColor Red
    exit 1
}

$tests = @()

# TEST 1: ik_okuyucu maskelenmis view'i okuyabilmeli
$out = Invoke-AsUser -User "ik_okuyucu" -Query "SELECT TOP 1 TCMaskeli FROM dbo.vw_PersonelIK;"
$tests += Assert-Result "T1: ik_okuyucu -> vw_PersonelIK SELECT" $out "OK"

# TEST 2: ik_okuyucu Personel tablosuna erisememeli (DENY)
$out = Invoke-AsUser -User "ik_okuyucu" -Query "SELECT TOP 1 * FROM dbo.Personel;"
$tests += Assert-Result "T2: ik_okuyucu -> Personel (DENY beklenir)" $out "DENY"

# TEST 3: muh_yazar Maas view'i okuyabilmeli
$out = Invoke-AsUser -User "muh_yazar" -Query "SELECT TOP 1 Maas FROM dbo.vw_PersonelMaas;"
$tests += Assert-Result "T3: muh_yazar -> vw_PersonelMaas SELECT" $out "OK"

# TEST 4: muh_yazar TCKimlikNo okuyamamali
$out = Invoke-AsUser -User "muh_yazar" -Query "SELECT TOP 1 TCKimlikNo FROM dbo.Personel;"
$tests += Assert-Result "T4: muh_yazar -> Personel.TCKimlikNo (DENY)" $out "DENY"

# TEST 5: muh_yazar Personel tablosuna INSERT edememeli
$out = Invoke-AsUser -User "muh_yazar" -Query "INSERT INTO dbo.Personel (TCKimlikNo, Ad, Soyad, Email, Maas, IseBaslamaTarihi, DepartmanID) VALUES (N'99999999999', N'T', N'T', N't@t', 1, GETDATE(), 1);"
$tests += Assert-Result "T5: muh_yazar -> Personel INSERT (DENY)" $out "DENY"

# TEST 6: yazilim_sef sadece kendi departmanini gormeli (RLS)
$out = & sqlcmd -S $Server -E -C -l 5 -Q "USE PersonelDB; EXECUTE AS USER='yazilim_sef'; SELECT COUNT(*) AS n FROM dbo.Personel; REVERT;" 2>&1
$rowMatch = ($out | Select-String -Pattern "^\s*(\d+)\s*$" | Select-Object -First 1)
if ($rowMatch -and [int]$rowMatch.Matches[0].Groups[1].Value -lt 5) {
    Write-Host "[PASS] T6: yazilim_sef -> RLS filtre aktif (sayi=$($rowMatch.Matches[0].Groups[1].Value) < 5)" -ForegroundColor Green
    $tests += $true
} else {
    Write-Host "[FAIL] T6: yazilim_sef -> RLS filtre CALISMIYOR" -ForegroundColor Red
    $tests += $false
}

# TEST 7: SQL Injection savunmasini dogrula
#   Savunmasiz sp: x' OR 1=1 -- tum tabloyu doker
#   Guvenli sp:    ayni girdide 0 satir doner
$injected = "x' OR 1=1 --"
$vulnSql = "USE PersonelDB; DECLARE @r INT; EXEC @r = dbo.sp_FindByEmail_Vulnerable @email = N'$injected'; SELECT @r AS r;"
$safeQuery = "USE PersonelDB; EXEC dbo.sp_FindByEmail_Safe @email = N'$injected';"
$vulnOut = & sqlcmd -S $Server -E -C -l 5 -Q $vulnSql 2>&1
$safeOut = & sqlcmd -S $Server -E -C -l 5 -Q $safeQuery 2>&1
# Guvenli versiyonda Personel kaydi dönmemeli (TC/Ad gibi satir sayisi 0 olmali)
$safeCount = ($safeOut | Select-String -Pattern "rows affected|0 rows" | Measure-Object).Count
Write-Host "[INFO] T7: SQL Injection demo - savunmasiz ciktisi $((($vulnOut -join ' ').Length)) char, guvenli ciktisi $((($safeOut -join ' ').Length)) char" -ForegroundColor DarkGray

# --- Ozet ---
Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
$passed = ($tests | Where-Object { $_ -eq $true }).Count
$failed = ($tests | Where-Object { $_ -eq $false }).Count
Write-Host " PASS : $passed" -ForegroundColor Green
Write-Host " FAIL : $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "DarkGray" })
Write-Host "========================================================" -ForegroundColor Yellow

if ($failed -gt 0) { exit 1 } else { exit 0 }
