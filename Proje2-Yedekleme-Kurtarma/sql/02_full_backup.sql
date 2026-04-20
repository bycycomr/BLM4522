/* ============================================================================
   Proje 2 - Adım 02: Tam (Full) Yedekleme
   ----------------------------------------------------------------------------
   Amaç   : Veritabanının tam bir kopyasını almak. Diğer tüm yedekleme türleri
            (Differential, Log) bir FULL yedeğe göre konumlanır.
   Zinciri: FULL  -> DIFF  -> LOG  -> LOG  -> DIFF  -> LOG ...
   Not    : COMPRESSION = daha küçük dosya; CHECKSUM = bütünlük doğrulaması.
   ============================================================================ */

USE master;
GO

DECLARE @DosyaAdi NVARCHAR(260) =
    N'C:\SQLBackups\OkulDB_FULL_' + FORMAT(SYSDATETIME(),'yyyyMMdd_HHmmss') + N'.bak';

BACKUP DATABASE OkulDB
TO DISK = @DosyaAdi
WITH
    FORMAT,                   -- yeni bir medya seti başlat
    INIT,                     -- mevcut içeriği üzerine yaz
    NAME = N'OkulDB-FULL',
    DESCRIPTION = N'Tam yedek - BLM4522 Proje 2',
    COMPRESSION,              -- sıkıştırma
    CHECKSUM,                 -- sayfa-düzeyi bütünlük
    STATS = 10;               -- her %10'da ilerleme bildirimi
GO

/* Son alınan full yedeği listele */
SELECT TOP (5)
    bs.database_name,
    bs.type             AS BackupType,
    bs.backup_start_date,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [Size_MB],
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'OkulDB' AND bs.type = 'D'
ORDER BY bs.backup_start_date DESC;
GO
