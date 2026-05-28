/* ============================================================================
   BLM4522 - Proje 1: Veritabani Performans Optimizasyonu ve Izleme
   ----------------------------------------------------------------------------
   04_disk_ve_yogunluk.sql
   Gereksinim 2 : Disk alani ve veri yogunlugu yonetimi.
   Icerik:
     A) Tablo bazli disk kullanimi (veri / indeks / bos alan)
     B) Veri yogunlugu = fragmentasyon ve sayfa doluluk orani
     C) Fragmentasyon giderme: REORGANIZE / REBUILD + UPDATE STATISTICS
     D) Veri sikistirma (ROW/PAGE) ile disk tasarrufu
   Calistirma: sqlcmd -S . -E -C -I -b -i 04_disk_ve_yogunluk.sql
   ============================================================================ */
SET NOCOUNT ON;
USE SatisDB;
GO

/* ===========================================================================
   A) DISK KULLANIMI - tablo bazinda (veri / indeks / kullanilmayan)
   =========================================================================== */
PRINT '--- Tablo bazli disk kullanimi ---';
SELECT  t.name                                              AS Tablo,
        p.rows                                              AS SatirSayisi,
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(10,2)) AS Ayrilan_MB,
        CAST(SUM(a.used_pages)  * 8.0 / 1024 AS DECIMAL(10,2)) AS Kullanilan_MB,
        CAST(SUM(a.data_pages)  * 8.0 / 1024 AS DECIMAL(10,2)) AS Veri_MB
FROM       sys.tables t
JOIN       sys.partitions p      ON p.object_id = t.object_id AND p.index_id IN (0,1)
JOIN       sys.allocation_units a ON a.container_id = p.partition_id
GROUP BY t.name, p.rows
ORDER BY Ayrilan_MB DESC;
GO

-- Veritabani dosya seviyesinde kullanilan / bos alan
PRINT '--- Veri dosyasi doluluk ---';
SELECT  name                                                       AS DosyaAdi,
        CAST(size * 8.0 / 1024 AS DECIMAL(10,2))                   AS Ayrilan_MB,
        CAST(FILEPROPERTY(name,'SpaceUsed') * 8.0 / 1024 AS DECIMAL(10,2)) AS Kullanilan_MB,
        CAST((size - FILEPROPERTY(name,'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(10,2)) AS Bos_MB
FROM    sys.database_files;
GO

/* ===========================================================================
   B) VERI YOGUNLUGU / FRAGMENTASYON
   avg_fragmentation_in_percent : sayfalarin fiziksel dagilim duzensizligi
   avg_page_space_used_in_percent: sayfa doluluk orani (yogunluk)
   Kural (Microsoft onerisi):  >%5 ve <=%30  -> REORGANIZE
                               >%30           -> REBUILD
   =========================================================================== */
PRINT '--- Fragmentasyon / yogunluk ---';
SELECT  OBJECT_NAME(ps.object_id)                  AS Tablo,
        i.name                                     AS Indeks,
        ps.index_type_desc                         AS Tip,
        ps.page_count                              AS SayfaSayisi,
        CAST(ps.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS Fragmentasyon_Yuzde,
        CAST(ps.avg_page_space_used_in_percent AS DECIMAL(5,2)) AS SayfaDoluluk_Yuzde,
        CASE
            WHEN ps.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
            WHEN ps.avg_fragmentation_in_percent > 5  THEN 'REORGANIZE'
            ELSE 'OK'
        END                                        AS Oneri
FROM       sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ps
JOIN       sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE  ps.page_count > 100        -- kucuk indeksler icin fragmentasyon onemsiz
ORDER BY ps.avg_fragmentation_in_percent DESC;
GO

/* ===========================================================================
   C) FRAGMENTASYON GIDERME + ISTATISTIK GUNCELLEME
   Demo amacli en buyuk tablonun clustered indeksini REBUILD ediyoruz.
   FILLFACTOR = 90 : ileride yapilacak insert'ler icin sayfada %10 bosluk birak
   (boylece page split / fragmentasyon yavaslar).
   =========================================================================== */
PRINT '--- SiparisDetay REBUILD + UPDATE STATISTICS ---';
ALTER INDEX PK_SiparisDetay ON dbo.SiparisDetay REBUILD WITH (FILLFACTOR = 90);
ALTER INDEX ALL ON dbo.Siparis REORGANIZE;
UPDATE STATISTICS dbo.SiparisDetay WITH FULLSCAN;
UPDATE STATISTICS dbo.Siparis      WITH FULLSCAN;
GO

/* ===========================================================================
   D) VERI SIKISTIRMA (Data Compression)
   En buyuk tabloyu PAGE sikistirma ile kuculterek disk + I/O tasarrufu.
   Once tahmini kazanci olc, sonra uygula.
   (PAGE sikistirma Developer/Enterprise/Standard 2016 SP1+ surumlerde calisir.)
   =========================================================================== */
PRINT '--- Sikistirma tahmini (PAGE) ---';
EXEC sys.sp_estimate_data_compression_savings
     @schema_name = 'dbo', @object_name = 'SiparisDetay',
     @index_id = NULL, @partition_number = NULL, @data_compression = 'PAGE';
GO

PRINT '--- PAGE sikistirma uygulaniyor ---';
ALTER TABLE dbo.SiparisDetay REBUILD WITH (DATA_COMPRESSION = PAGE);
GO

-- Sikistirma sonrasi yeni boyut
PRINT '--- Sikistirma sonrasi SiparisDetay boyutu ---';
EXEC sys.sp_spaceused 'dbo.SiparisDetay';
GO

PRINT '== 04_disk_ve_yogunluk.sql TAMAMLANDI ==';
GO
