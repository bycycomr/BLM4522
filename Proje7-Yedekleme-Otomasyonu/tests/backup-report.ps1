<#
================================================================================
 BLM4522 - Proje 7: PowerShell Yedek Raporu
--------------------------------------------------------------------------------
 msdb yedek gecmisini sorgulayip konsola ozet rapor basar (PowerShell ornegi).
 Kullanim: PS> .\backup-report.ps1   |   PS> .\backup-report.ps1 -Server "."
================================================================================
#>
[CmdletBinding()]
param([string]$Server = ".", [string]$Database = "OtomasyonDB")

$query = @"
SET NOCOUNT ON;
SELECT
  CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' END AS Tip,
  CONVERT(varchar(19), bs.backup_finish_date, 120) AS Bitis,
  CAST(bs.backup_size/1048576.0 AS DECIMAL(10,2)) AS MB
FROM msdb.dbo.backupset bs
WHERE bs.database_name = '$Database'
ORDER BY bs.backup_finish_date DESC;
"@

Write-Host ""
Write-Host "=== Proje 7 - $Database Yedek Raporu ($Server) ===" -ForegroundColor Yellow

$ping = & sqlcmd -S $Server -E -C -l 5 -h -1 -W -Q "SELECT 1" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] SQL Server'a baglanilamadi. (net start MSSQLSERVER)" -ForegroundColor Red
    exit 1
}

$rows = & sqlcmd -S $Server -E -C -W -s "|" -Q $query 2>&1
$rows | Where-Object { $_ -and $_ -notmatch '^\(' -and $_ -notmatch 'rows affected' } | ForEach-Object {
    if ($_ -match '^-+') { return }
    Write-Host $_
}

# Basit saglik kontrolu: son FULL 24 saatten eski mi?
$lastFull = & sqlcmd -S $Server -E -C -h -1 -W -Q "SET NOCOUNT ON; SELECT ISNULL(CONVERT(varchar(19),MAX(backup_finish_date),120),'YOK') FROM msdb.dbo.backupset WHERE database_name='$Database' AND type='D';" 2>&1
Write-Host ""
Write-Host "Son FULL yedek: $($lastFull -join ' ')" -ForegroundColor Cyan
