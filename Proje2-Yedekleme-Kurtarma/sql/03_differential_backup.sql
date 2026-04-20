/* ============================================================================
   Proje 2 - Adım 03: Fark (Differential) Yedekleme
   ----------------------------------------------------------------------------
   Amaç   : Son FULL yedekten bu yana DEĞİŞEN extent'leri yedekle. Bu sayede
            restore süresi kısalır: FULL + son DIFF = tam anlık görüntü.
   Şart   : Daha önce en az bir FULL yedek alınmış olmalıdır.
   Örnek  : Önce birkaç veri değişikliği yap, sonra DIFF al.
   ============================================================================ */

USE OkulDB;
GO

/* 1) Önce bir miktar veri değişikliği yapalım ki DIFF anlamlı olsun */
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'Zeynep', N'Arslan', N'20200006', N'Bilgisayar Mühendisliği'),
 (N'Emre',   N'Polat',  N'20200007', N'Bilgisayar Mühendisliği');

UPDATE dbo.[Not] SET Vize = 95 WHERE OgrenciID = 1 AND DersID = 1;

INSERT INTO dbo.[Not] (OgrenciID, DersID, Vize, Final) VALUES
 (6, 1, 85, 90),
 (7, 1, 65, 70);
GO

/* 2) Fark yedeği al */
USE master;
GO

DECLARE @DosyaAdi NVARCHAR(260) =
    N'C:\SQLBackups\OkulDB_DIFF_' + FORMAT(SYSDATETIME(),'yyyyMMdd_HHmmss') + N'.bak';

BACKUP DATABASE OkulDB
TO DISK = @DosyaAdi
WITH
    DIFFERENTIAL,
    INIT,
    NAME = N'OkulDB-DIFF',
    DESCRIPTION = N'Fark yedeği - BLM4522 Proje 2',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO

SELECT TOP (5)
    bs.type AS BackupType,        -- I = Differential
    bs.backup_start_date,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS Size_MB,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'I'
ORDER BY bs.backup_start_date DESC;
GO
