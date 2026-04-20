/* ============================================================================
   Proje 2 - Adım 04: İşlem Günlüğü (Transaction Log) Yedekleme
   ----------------------------------------------------------------------------
   Amaç   : En son yedekten bu yana işlenen TÜM transaction'ları yedekle.
            Point-in-time (PITR) restore yalnızca log yedekleri ile mümkündür.
   Şart   : RECOVERY MODEL = FULL (veya BULK_LOGGED).
   Önemli : Log yedeği alındıkça log dosyası "truncate" olur (boşa çıkar) ve
            sürekli büyümesi önlenir. Bu yüzden üretimde log backup şarttır.
   ============================================================================ */

USE OkulDB;
GO

/* Veri değişikliği (log'a yazılacak) */
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'Selin', N'Aydın', N'20200008', N'Bilgisayar Mühendisliği');

UPDATE dbo.Ogrenci SET Bolum = N'Yazılım Mühendisliği' WHERE Numara = N'20200002';
GO

/* --- Log backup --- */
USE master;
GO

DECLARE @DosyaAdi NVARCHAR(260) =
    N'C:\SQLBackups\OkulDB_LOG_' + FORMAT(SYSDATETIME(),'yyyyMMdd_HHmmss') + N'.trn';

BACKUP LOG OkulDB
TO DISK = @DosyaAdi
WITH
    INIT,
    NAME = N'OkulDB-LOG',
    DESCRIPTION = N'İşlem günlüğü yedeği - BLM4522 Proje 2',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO

/* Son log yedeklerini listele (type = 'L') */
SELECT TOP (10)
    bs.type AS BackupType,
    bs.backup_start_date,
    bs.first_lsn,
    bs.last_lsn,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS Size_MB,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'L'
ORDER BY bs.backup_start_date DESC;
GO
