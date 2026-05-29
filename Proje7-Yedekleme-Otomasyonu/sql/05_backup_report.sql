/* ============================================================================
   BLM4522 - Proje 7: Yedekleme ve Otomasyon
   ----------------------------------------------------------------------------
   05_backup_report.sql
   Amac : Yedeklerin duzenli alindigini gosteren RAPOR (msdb gecmisinden).
   Kaynak: msdb.dbo.backupset (type: D=Full, I=Diff, L=Log)
   Calistirma: sqlcmd -S . -E -C -I -b -i 05_backup_report.sql
   ============================================================================ */
SET NOCOUNT ON;
USE msdb;
GO

/* --- 1) Her veritabaninin son Full/Diff/Log yedek zamani + yas --- */
PRINT '--- Veritabani basina son yedekler ---';
SELECT
    d.name AS Veritabani,
    MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS Son_FULL,
    MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS Son_DIFF,
    MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS Son_LOG
FROM       sys.databases d
LEFT JOIN  msdb.dbo.backupset bs ON bs.database_name = d.name
WHERE  d.database_id > 4    -- sistem DB'lerini ele
GROUP BY d.name
ORDER BY d.name;
GO

/* --- 2) OtomasyonDB icin son 10 yedek (tip, boyut, sure) --- */
PRINT '--- OtomasyonDB son yedekler (detay) ---';
SELECT TOP 10
    CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' ELSE bs.type END AS Tip,
    bs.backup_finish_date AS Bitis,
    CAST(bs.backup_size      / 1048576.0 AS DECIMAL(10,2)) AS Boyut_MB,
    CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS Sikistirilmis_MB,
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS Sure_sn,
    mf.physical_device_name AS Dosya
FROM       msdb.dbo.backupset bs
JOIN       msdb.dbo.backupmediafamily mf ON mf.media_set_id = bs.media_set_id
WHERE  bs.database_name = N'OtomasyonDB'
ORDER BY bs.backup_finish_date DESC;
GO

/* --- 3) Yedek sagligi: FULL > 1 gun veya LOG > 1 saat ise UYARI --- */
PRINT '--- Yedek saglik durumu (OtomasyonDB) ---';
SELECT
    N'OtomasyonDB' AS Veritabani,
    CASE WHEN DATEDIFF(HOUR, MAX(CASE WHEN type='D' THEN backup_finish_date END), SYSDATETIME()) > 24
         THEN 'UYARI: FULL guncel degil' ELSE 'OK: FULL guncel' END AS Full_Durum,
    CASE WHEN MAX(CASE WHEN type='L' THEN backup_finish_date END) IS NULL THEN 'LOG yok'
         WHEN DATEDIFF(MINUTE, MAX(CASE WHEN type='L' THEN backup_finish_date END), SYSDATETIME()) > 60
         THEN 'UYARI: LOG guncel degil' ELSE 'OK: LOG guncel' END AS Log_Durum
FROM msdb.dbo.backupset WHERE database_name = N'OtomasyonDB';
GO

/* --- 4) Proje7 Agent job'larinin son calisma gecmisi --- */
PRINT '--- Proje7 job calisma gecmisi (Agent calistiysa) ---';
SELECT TOP 10
    j.name AS Job,
    CASE h.run_status WHEN 0 THEN 'BASARISIZ' WHEN 1 THEN 'BASARILI'
         WHEN 2 THEN 'YENIDEN DENE' WHEN 3 THEN 'IPTAL' ELSE 'BILINMIYOR' END AS Durum,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS Calisma_Zamani,
    h.message AS Mesaj
FROM       msdb.dbo.sysjobs j
LEFT JOIN  msdb.dbo.sysjobhistory h ON h.job_id = j.job_id AND h.step_id = 0
WHERE  j.name LIKE 'Proje7_%'
ORDER BY h.run_date DESC, h.run_time DESC;
GO

PRINT '== 05_backup_report.sql TAMAMLANDI ==';
GO
