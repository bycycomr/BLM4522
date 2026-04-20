/* ============================================================================
   Proje 2 - Adım 06: Point-in-Time Restore (PITR)
   ----------------------------------------------------------------------------
   Senaryo: Saat 14:35'te bir kullanıcı yanlışlıkla DELETE FROM ... çalıştırdı.
            Veriyi 14:34:59 anına geri döndürmek istiyoruz.
   Plan   : FULL -> DIFF -> LOG zincirini sırasıyla NORECOVERY ile yükle,
            son LOG'u STOPAT = 'yyyy-MM-ddTHH:mm:ss' ile uygula, RECOVERY.
   ----------------------------------------------------------------------------
   Bu script genel bir şablondur: @StopAt değerini yanlış işlemden hemen önceki
   zaman olarak düzenleyin.
   ============================================================================ */

USE master;
GO

DECLARE @StopAt DATETIME2(0) = '2026-04-20T14:34:59';   -- <== güncelleyin
DECLARE @SonFull NVARCHAR(260), @SonDiff NVARCHAR(260);

/* 1) Son FULL */
SELECT TOP (1) @SonFull = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'D'
ORDER BY bs.backup_start_date DESC;

/* 2) @SonFull'dan sonra alınmış en yeni DIFF (varsa) */
SELECT TOP (1) @SonDiff = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB'
  AND bs.type = 'I'
  AND bs.backup_start_date < @StopAt
ORDER BY bs.backup_start_date DESC;

PRINT N'FULL : ' + ISNULL(@SonFull, N'(yok)');
PRINT N'DIFF : ' + ISNULL(@SonDiff, N'(yok)');

IF DB_ID(N'OkulDB') IS NOT NULL
    ALTER DATABASE OkulDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

/* 3) FULL'u NORECOVERY ile uygula */
RESTORE DATABASE OkulDB
FROM DISK = @SonFull
WITH REPLACE, NORECOVERY, STATS = 10;

/* 4) DIFF varsa uygula */
IF @SonDiff IS NOT NULL
    RESTORE DATABASE OkulDB
    FROM DISK = @SonDiff
    WITH NORECOVERY, STATS = 10;

/* 5) Tüm LOG yedeklerini sırayla uygula; son log'a STOPAT koy */
DECLARE @LogPath NVARCHAR(260), @IlkLsn NUMERIC(25,0), @SonLsn NUMERIC(25,0);

DECLARE log_cursor CURSOR FAST_FORWARD FOR
    SELECT bmf.physical_device_name, bs.first_lsn, bs.last_lsn
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = N'OkulDB' AND bs.type = 'L'
      AND bs.backup_start_date >= (
            SELECT MAX(backup_start_date) FROM msdb.dbo.backupset
            WHERE database_name = N'OkulDB' AND type IN ('D','I')
              AND backup_start_date <= @StopAt)
    ORDER BY bs.backup_start_date;

OPEN log_cursor;
FETCH NEXT FROM log_cursor INTO @LogPath, @IlkLsn, @SonLsn;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @Cmd NVARCHAR(MAX) = N'RESTORE LOG OkulDB FROM DISK = N''' + @LogPath + N''' WITH NORECOVERY, STOPAT = ''' + CONVERT(NVARCHAR(25), @StopAt, 126) + N''';';
    PRINT @Cmd;
    EXEC (@Cmd);
    FETCH NEXT FROM log_cursor INTO @LogPath, @IlkLsn, @SonLsn;
END
CLOSE log_cursor;
DEALLOCATE log_cursor;

/* 6) DB'yi kullanıma aç */
RESTORE DATABASE OkulDB WITH RECOVERY;
ALTER DATABASE OkulDB SET MULTI_USER;
GO

PRINT N'>>> Point-in-time restore tamamlandı.';
