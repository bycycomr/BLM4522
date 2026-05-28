/* ============================================================================
   BLM4522 - Proje 1: Veritabani Performans Optimizasyonu ve Izleme
   ----------------------------------------------------------------------------
   02_izleme_ve_analiz.sql
   Gereksinim 3 : SQL Profiler / DMV ile sorgu performansini izleme.
   Gereksinim 5 : Uzun suren sorgularin analizi.
   Bu adim SADECE OLCUM yapar (optimizasyon yok). Burada gordugumuz yuksek
   "logical reads" / scan degerleri, 03_indeksleme.sql sonrasi tekrar olculup
   karsilastirilacaktir (before/after).
   Calistirma: sqlcmd -S . -E -C -I -b -i 02_izleme_ve_analiz.sql
   ============================================================================ */
SET NOCOUNT ON;
USE SatisDB;
GO

/* ---------------------------------------------------------------------------
   1) BASELINE: Temsili "yavas" sorgu  (henuz indeks yok -> scan beklenir)
   Senaryo: Istanbul'lu musterilerin 2025 yilindaki toplam ciro'su.
   STATISTICS IO  -> kac mantiksal sayfa okundu (logical reads)
   STATISTICS TIME-> CPU ve gecen sure (ms)
   --------------------------------------------------------------------------- */
PRINT '--- BASELINE (indeks ONCESI) ---';
DBCC DROPCLEANBUFFERS;   -- temiz olcum icin cache temizle (test ortami)
SET STATISTICS IO  ON;
SET STATISTICS TIME ON;

SELECT  m.Sehir,
        COUNT(DISTINCT s.SiparisID)            AS SiparisSayisi,
        SUM(sd.Adet * sd.BirimFiyat)           AS ToplamCiro
FROM        dbo.Musteri      m
JOIN        dbo.Siparis      s  ON s.MusteriID = m.MusteriID
JOIN        dbo.SiparisDetay sd ON sd.SiparisID = s.SiparisID
WHERE   m.Sehir = N'Istanbul'
  AND   s.SiparisTarihi >= '2025-01-01'
  AND   s.SiparisTarihi <  '2026-01-01'
GROUP BY m.Sehir;

SET STATISTICS IO  OFF;
SET STATISTICS TIME OFF;
GO

/* ---------------------------------------------------------------------------
   2) DMV - EKSIK INDEKS ONERILERI (Missing Index)
   SQL Server, optimizer'in "olsaydi iyiydi" dedigi indeksleri burada biriktirir.
   improvement_measure = beklenen toplam fayda (yuksek = oncelikli).
   --------------------------------------------------------------------------- */
PRINT '--- DMV: Eksik indeks onerileri ---';
SELECT TOP 10
       ROUND(s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans), 0) AS improvement_measure,
       d.statement                       AS Tablo,
       d.equality_columns                AS EsitlikSutunlari,
       d.inequality_columns              AS AralikSutunlari,
       d.included_columns                AS IncludeSutunlari,
       s.user_seeks, s.user_scans
FROM       sys.dm_db_missing_index_groups        g
JOIN       sys.dm_db_missing_index_group_stats   s ON s.group_handle = g.index_group_handle
JOIN       sys.dm_db_missing_index_details       d ON d.index_handle = g.index_handle
WHERE  d.database_id = DB_ID()
ORDER BY improvement_measure DESC;
GO

/* ---------------------------------------------------------------------------
   3) DMV - EN PAHALI SORGULAR (cache'teki plan istatistiklerinden)
   Toplam mantiksal okuma ve CPU'ya gore en agir 10 sorgu.
   --------------------------------------------------------------------------- */
PRINT '--- DMV: En pahali sorgular ---';
SELECT TOP 10
       qs.execution_count                                   AS CalismaSayisi,
       qs.total_logical_reads                               AS ToplamMantiksalOkuma,
       qs.total_logical_reads / qs.execution_count          AS OrtMantiksalOkuma,
       qs.total_worker_time / 1000                          AS ToplamCPU_ms,
       qs.total_elapsed_time / 1000                         AS ToplamSure_ms,
       SUBSTRING(t.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS SorguMetni
FROM       sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
ORDER BY qs.total_logical_reads DESC;
GO

/* ---------------------------------------------------------------------------
   4) DMV - BEKLEME ISTATISTIKLERI (Wait Stats)
   Sistem neyi bekliyor? (CPU mu, disk I/O mu, kilit mi)
   --------------------------------------------------------------------------- */
PRINT '--- DMV: En cok beklenen kaynaklar ---';
SELECT TOP 10
       wait_type,
       waiting_tasks_count                       AS BeklemeAdedi,
       wait_time_ms                              AS ToplamBekleme_ms,
       wait_time_ms / NULLIF(waiting_tasks_count,0) AS OrtBekleme_ms
FROM   sys.dm_os_wait_stats
WHERE  wait_type NOT IN  -- anlamsiz/arka plan beklemelerini ele
       (N'CLR_SEMAPHORE',N'LAZYWRITER_SLEEP',N'RESOURCE_QUEUE',N'SLEEP_TASK',
        N'SLEEP_SYSTEMTASK',N'SQLTRACE_BUFFER_FLUSH',N'WAITFOR',N'BROKER_TASK_STOP',
        N'XE_TIMER_EVENT',N'XE_DISPATCHER_WAIT',N'DIRTY_PAGE_POLL',N'HADR_FILESTREAM_IOMGR_IOCOMPLETION')
  AND  waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;
GO

/* ---------------------------------------------------------------------------
   5) DMV - INDEKS KULLANIMI (03 ve 05 icin temel)
   user_seeks/scans/lookups = okuma; user_updates = bakim maliyeti.
   Hic okunmayan (seeks+scans+lookups = 0) ama guncellenen indeks = GEREKSIZ.
   --------------------------------------------------------------------------- */
PRINT '--- DMV: Indeks kullanim istatistikleri ---';
SELECT  OBJECT_NAME(i.object_id)            AS Tablo,
        i.name                              AS Indeks,
        i.type_desc                         AS Tip,
        ISNULL(us.user_seeks,0)             AS Seek,
        ISNULL(us.user_scans,0)             AS Scan,
        ISNULL(us.user_lookups,0)           AS Lookup,
        ISNULL(us.user_updates,0)           AS Guncelleme
FROM       sys.indexes i
LEFT JOIN  sys.dm_db_index_usage_stats us
       ON  us.object_id = i.object_id AND us.index_id = i.index_id AND us.database_id = DB_ID()
WHERE  i.object_id > 100 AND i.name IS NOT NULL
ORDER BY Tablo, Indeks;
GO

/* ---------------------------------------------------------------------------
   6) SQL PROFILER ESDEGERI: Extended Events (XEvents) ile izleme
   Profiler GUI'dir; modern ve hafif esdegeri Extended Events'tir.
   Asagidaki oturum 100 ms'den uzun suren sorgulari yakalar.
   (Acmak/durdurmak icin yorumlu birakildi; raporda anlatilmistir.)
   --------------------------------------------------------------------------- */
/*
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'YavasSorgular')
    DROP EVENT SESSION YavasSorgular ON SERVER;
CREATE EVENT SESSION YavasSorgular ON SERVER
ADD EVENT sqlserver.sql_statement_completed
    (ACTION (sqlserver.sql_text, sqlserver.database_name)
     WHERE  duration > 100000)        -- mikro saniye: 100 ms
ADD TARGET package0.ring_buffer;
ALTER EVENT SESSION YavasSorgular ON SERVER STATE = START;
-- ... is yukunu calistir ...
-- Yakalananlari oku:
SELECT CAST(target_data AS XML) FROM sys.dm_xe_session_targets t
JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
WHERE s.name = N'YavasSorgular';
ALTER EVENT SESSION YavasSorgular ON SERVER STATE = STOP;
*/
PRINT '== 02_izleme_ve_analiz.sql TAMAMLANDI ==';
GO
