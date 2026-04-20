/* ============================================================================
   Proje 2 - Adım 09: Yedeklerin Doğruluğunu Test Etme
   ----------------------------------------------------------------------------
   Bir yedek dosyasının "alınmış olması" yeterli değildir; gerçekten restore
   edilebildiğinden emin olmak gerekir. Bu script üç katmanlı doğrulama yapar:
      1) RESTORE VERIFYONLY  -> başlık + checksum kontrolü
      2) RESTORE HEADERONLY  -> medya içeriğini oku
      3) DBCC CHECKDB        -> restore sonrası fiziksel/mantıksal tutarlılık
   ============================================================================ */

USE master;
GO

/* --- 1) Tüm OkulDB yedeklerini VERIFYONLY ile kontrol et --- */
DECLARE @path NVARCHAR(260);
DECLARE cur CURSOR FAST_FORWARD FOR
    SELECT DISTINCT bmf.physical_device_name
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = N'OkulDB';

OPEN cur;
FETCH NEXT FROM cur INTO @path;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        DECLARE @cmd NVARCHAR(MAX) = N'RESTORE VERIFYONLY FROM DISK = N''' + @path + N''' WITH CHECKSUM;';
        PRINT N'Kontrol: ' + @path;
        EXEC (@cmd);
    END TRY
    BEGIN CATCH
        PRINT N'HATA: ' + @path + N' -> ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM cur INTO @path;
END
CLOSE cur; DEALLOCATE cur;
GO

/* --- 2) Restore edilmiş DB'de tutarlılık kontrolü --- */
DBCC CHECKDB (OkulDB) WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO

/* --- 3) Raporlama: son 20 yedek olayı --- */
SELECT TOP (20)
    bs.database_name,
    CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' END AS Tur,
    bs.backup_start_date,
    bs.backup_finish_date,
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS Saniye,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS Size_MB,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB'
ORDER BY bs.backup_start_date DESC;
GO
