/* ============================================================================
   Proje 2 - Adım 05: Tam Yedekten Geri Yükleme (Restore)
   ----------------------------------------------------------------------------
   Senaryo: Sadece son FULL yedeğe geri dönmek istiyoruz (veri kaybı kabul).
   ----------------------------------------------------------------------------
   İpucu  : RESTORE DATABASE ... WITH REPLACE    -> mevcut DB'nin üzerine yaz
            NORECOVERY                            -> zincir devam edecek
            RECOVERY                              -> son adım, DB kullanıma aç
   ============================================================================ */

USE master;
GO

/* 1) Alınan FULL yedeklerden en sonuncusunun yolunu bulalım */
DECLARE @SonFull NVARCHAR(260);
SELECT TOP (1) @SonFull = bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'D'
ORDER BY bs.backup_start_date DESC;

IF @SonFull IS NULL
BEGIN
    RAISERROR('Hiç FULL yedek bulunamadı. Önce 02_full_backup.sql çalıştırın.',16,1);
    RETURN;
END

PRINT N'Geri yüklenecek FULL: ' + @SonFull;

/* 2) DB'yi single user'a al (aktif bağlantıları kapatır) */
IF DB_ID(N'OkulDB') IS NOT NULL
    ALTER DATABASE OkulDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

/* 3) Restore */
RESTORE DATABASE OkulDB
FROM DISK = @SonFull
WITH
    REPLACE,
    RECOVERY,
    STATS = 10;

ALTER DATABASE OkulDB SET MULTI_USER;
GO

/* 4) Doğrulama */
USE OkulDB;
SELECT COUNT(*) AS OgrenciSayisi FROM dbo.Ogrenci;
GO
