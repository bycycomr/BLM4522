<#
================================================================================
 Proje 2 - Yedekleme ve Felaketten Kurtarma
 Ucdan Uca Disaster-Recovery Demo
--------------------------------------------------------------------------------
 Amac : Butun yedekleme/kurtarma zincirini tek komutta demonstre etmek:
        1. OkulDB kurulumu
        2. FULL backup
        3. Ek veri ekle -> DIFF backup
        4. Biraz daha veri ekle -> LOG backup
        5. Guvenli ani kaydet (@StopAt)
        6. Yanlislikla tum Ogrenci tablosunu sil (felaket)
        7. Tail-log backup
        8. PITR: FULL + DIFF + LOG'lari sirayla, son LOG'a STOPAT uygula
        9. Kurtarma sonrasi satir sayisini dogrula
 Kullanim:
     PS> .\disaster-recovery-demo.ps1
     PS> .\disaster-recovery-demo.ps1 -Server "MAKINE\SQLEXPRESS"
================================================================================
#>

[CmdletBinding()]
param(
    [string]$Server = ".",
    [string]$BackupDir = "C:\SQLBackups"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
$SqlDir = Join-Path $ProjectRoot "sql"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutDir = Join-Path $ScriptRoot "output\demo_$Stamp"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Say($icon, $msg, $color) { Write-Host "$icon $msg" -ForegroundColor $color }
function Step($n, $msg) { Write-Host ""; Write-Host ("=" * 64) -ForegroundColor Yellow; Write-Host " ADIM $n - $msg" -ForegroundColor Yellow; Write-Host ("=" * 64) -ForegroundColor Yellow }

function Invoke-Sql {
    param([string]$Query, [string]$LogName)
    $logPath = Join-Path $OutDir "$LogName.log"
    $out = & sqlcmd -S $Server -E -C -b -Q $Query 2>&1
    $exit = $LASTEXITCODE
    $out | Out-File $logPath -Encoding UTF8
    if ($exit -ne 0) {
        Say "X" "SQL hatasi ($LogName)" "Red"
        $out | Select-Object -First 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
        throw "sqlcmd exit=$exit"
    }
    return $out
}

function Invoke-SqlFile {
    param([string]$File, [string]$LogName)
    $path = Join-Path $SqlDir $File
    $logPath = Join-Path $OutDir "$LogName.log"
    & sqlcmd -S $Server -E -C -b -i $path 2>&1 | Tee-Object -FilePath $logPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "$File basarisiz. Log: $logPath" }
}

# ==================== Baslangic ====================
Write-Host ""
Write-Host "################################################################" -ForegroundColor Cyan
Write-Host " BLM4522 - Proje 2: Disaster Recovery Demo" -ForegroundColor Cyan
Write-Host " Server    : $Server"
Write-Host " BackupDir : $BackupDir"
Write-Host " Output    : $OutDir"
Write-Host "################################################################" -ForegroundColor Cyan

# Baglanti kontrolu
$check = & sqlcmd -S $Server -E -C -l 5 -Q "SELECT 1" 2>&1
if ($LASTEXITCODE -ne 0) {
    Say "X" "SQL Server'a baglanilamadi. 'net start MSSQLSERVER' (admin) calistirin." "Red"
    exit 1
}
Say "+" "SQL Server erisilebilir." "Green"

# ==================== Adim 1: Setup ====================
Step 1 "OkulDB kurulumu (01_setup_database.sql)"
Invoke-SqlFile "01_setup_database.sql" "01_setup"
$initial = Invoke-Sql "SET NOCOUNT ON; SELECT COUNT(*) FROM OkulDB.dbo.Ogrenci;" "01_count"
Say "+" "Baslangic Ogrenci sayisi: $($initial | Select-String -Pattern '^\s*\d+' | Select-Object -First 1)" "Green"

# ==================== Adim 2: FULL backup ====================
Step 2 "FULL backup alma"
Invoke-SqlFile "02_full_backup.sql" "02_full"
Say "+" "FULL backup tamamlandi." "Green"

# ==================== Adim 3: Veri ekle + DIFF ====================
Step 3 "Ek veri insert + DIFF backup"
Invoke-Sql @"
USE OkulDB;
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'DemoKayit1', N'Test', N'90000001', N'Bilgisayar Muh.'),
 (N'DemoKayit2', N'Test', N'90000002', N'Bilgisayar Muh.');
"@ "03a_insert"
Invoke-SqlFile "03_differential_backup.sql" "03b_diff"
Say "+" "2 yeni ogrenci eklendi, DIFF alindi." "Green"

# ==================== Adim 4: Daha fazla veri + LOG ====================
Step 4 "Bir miktar daha veri + LOG backup"
Invoke-Sql @"
USE OkulDB;
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'DemoKayit3', N'Test', N'90000003', N'Elektrik'),
 (N'DemoKayit4', N'Test', N'90000004', N'Elektrik');
"@ "04a_insert"
Invoke-SqlFile "04_log_backup.sql" "04b_log"
Say "+" "Log backup alindi." "Green"

# ==================== Adim 5: Guvenli ani kaydet ====================
Step 5 "Guvenli zaman damgasini kaydet"
Start-Sleep -Seconds 2
$stopAtRaw = Invoke-Sql "SET NOCOUNT ON; SELECT CONVERT(NVARCHAR(25), SYSDATETIME(), 126);" "05_stopat"
$stopAt = ($stopAtRaw | Select-String -Pattern "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}" | Select-Object -First 1).Matches[0].Value
Say "+" "StopAt = $stopAt" "Green"

$beforeCount = (Invoke-Sql "SET NOCOUNT ON; SELECT COUNT(*) FROM OkulDB.dbo.Ogrenci;" "05_count") | Select-String -Pattern "^\s*(\d+)\s*$" | Select-Object -First 1
$beforeN = $beforeCount.Matches[0].Groups[1].Value
Say "i" "Felaket oncesi Ogrenci sayisi: $beforeN" "DarkGray"

Start-Sleep -Seconds 3  # StopAt'ten sonra felaketin ayri bir anda yasanmasi icin

# ==================== Adim 6: FELAKET ====================
Step 6 "!!! FELAKET: DELETE FROM dbo.Ogrenci (WHERE unutuldu)"
Invoke-Sql "USE OkulDB; DELETE FROM dbo.Ogrenci;" "06_disaster"
$afterDel = (Invoke-Sql "SET NOCOUNT ON; SELECT COUNT(*) FROM OkulDB.dbo.Ogrenci;" "06_after") | Select-String -Pattern "^\s*(\d+)\s*$" | Select-Object -First 1
$afterDelN = $afterDel.Matches[0].Groups[1].Value
Say "!" "Silme sonrasi satir: $afterDelN (beklenen 0)" "Red"

# ==================== Adim 7: Tail-log backup ====================
Step 7 "Tail-log backup (silme sonrasi son log parcasi)"
$tailFile = Join-Path $BackupDir "OkulDB_TAIL_$Stamp.trn"
Invoke-Sql "BACKUP LOG OkulDB TO DISK = N'$tailFile' WITH NO_TRUNCATE, INIT, CHECKSUM, NAME = N'OkulDB-TAIL';" "07_tail"
Say "+" "Tail-log: $tailFile" "Green"

# ==================== Adim 8: PITR ====================
Step 8 "Point-in-time restore (StopAt = $stopAt)"
$pitrQuery = @"
USE master;
SET NOCOUNT ON;
DECLARE @StopAt DATETIME2(0) = '$stopAt';
DECLARE @SonFull NVARCHAR(260), @SonDiff NVARCHAR(260);

SELECT TOP (1) @SonFull = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'D'
ORDER BY bs.backup_start_date DESC;

SELECT TOP (1) @SonDiff = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'I' AND bs.backup_start_date < @StopAt
ORDER BY bs.backup_start_date DESC;

PRINT N'FULL: ' + ISNULL(@SonFull, N'(yok)');
PRINT N'DIFF: ' + ISNULL(@SonDiff, N'(yok)');

IF DB_ID(N'OkulDB') IS NOT NULL
    ALTER DATABASE OkulDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE OkulDB FROM DISK = @SonFull WITH REPLACE, NORECOVERY, STATS = 25;
IF @SonDiff IS NOT NULL
    RESTORE DATABASE OkulDB FROM DISK = @SonDiff WITH NORECOVERY, STATS = 25;

DECLARE @LogPath NVARCHAR(260);
DECLARE log_cursor CURSOR FAST_FORWARD FOR
    SELECT bmf.physical_device_name
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = N'OkulDB' AND bs.type = 'L'
      AND bs.backup_start_date >= (
            SELECT MAX(backup_start_date) FROM msdb.dbo.backupset
            WHERE database_name = N'OkulDB' AND type IN ('D','I')
              AND backup_start_date <= @StopAt)
    ORDER BY bs.backup_start_date;

OPEN log_cursor;
FETCH NEXT FROM log_cursor INTO @LogPath;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @Cmd NVARCHAR(MAX) = N'RESTORE LOG OkulDB FROM DISK = N''' + @LogPath
        + N''' WITH NORECOVERY, STOPAT = ''' + CONVERT(NVARCHAR(25), @StopAt, 126) + N''';';
    PRINT @Cmd;
    EXEC (@Cmd);
    FETCH NEXT FROM log_cursor INTO @LogPath;
END
CLOSE log_cursor; DEALLOCATE log_cursor;

RESTORE DATABASE OkulDB WITH RECOVERY;
ALTER DATABASE OkulDB SET MULTI_USER;
PRINT N'>>> PITR tamamlandi.';
"@
Invoke-Sql $pitrQuery "08_pitr"
Say "+" "PITR tamamlandi." "Green"

# ==================== Adim 9: Dogrulama ====================
Step 9 "Kurtarma dogrulamasi"
$recovered = (Invoke-Sql "SET NOCOUNT ON; SELECT COUNT(*) FROM OkulDB.dbo.Ogrenci;" "09_verify") | Select-String -Pattern "^\s*(\d+)\s*$" | Select-Object -First 1
$recoveredN = $recovered.Matches[0].Groups[1].Value

Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host " SONUC" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host " Felaket oncesi  : $beforeN satir" -ForegroundColor Gray
Write-Host " Felaket sonrasi : $afterDelN satir" -ForegroundColor Red
Write-Host " Kurtarma sonrasi: $recoveredN satir" -ForegroundColor Green
Write-Host ""

if ([int]$recoveredN -eq [int]$beforeN) {
    Say "+" "BASARILI: Tum veri @StopAt anina geri getirildi." "Green"
    Write-Host ""
    Write-Host " Log'lar: $OutDir"
    exit 0
} else {
    Say "X" "BASARISIZ: satir sayisi eslemiyor ($recoveredN != $beforeN)" "Red"
    Write-Host " Log'lar: $OutDir"
    exit 1
}
