/* ============================================================================
   BLM4522 - Proje 5: Veri Temizleme ve ETL
   ----------------------------------------------------------------------------
   05_quality_report.sql
   Amac : Temizlik ONCESI (ham) ve SONRASI (hedef DimMusteri) veri kalitesini
          yan yana karsilastiran bir rapor uretir.
   Calistirma: sqlcmd -S . -E -C -I -b -i 05_quality_report.sql
   ============================================================================ */
SET NOCOUNT ON;
USE TemizlemeDB;
GO

PRINT '--- VERI KALITESI: ONCESI vs SONRASI ---';
SELECT 'Toplam satir' AS Metrik,
       (SELECT COUNT(*) FROM dbo.vw_ham_musteri) AS Oncesi_Ham,
       (SELECT COUNT(*) FROM dbo.DimMusteri)     AS Sonrasi_Hedef
UNION ALL SELECT 'Gecerli/dolu email',
       (SELECT SUM(CASE WHEN email IS NOT NULL AND email LIKE '%_@_%._%' AND email NOT LIKE '% %' THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri),
       (SELECT COUNT(email) FROM dbo.DimMusteri)
UNION ALL SELECT 'Bas/son bosluklu ad',
       (SELECT SUM(CASE WHEN ad IS NOT NULL AND ad <> LTRIM(RTRIM(ad)) THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri),
       (SELECT SUM(CASE WHEN ad IS NOT NULL AND ad <> LTRIM(RTRIM(ad)) THEN 1 ELSE 0 END) FROM dbo.DimMusteri)
UNION ALL SELECT 'Farkli sehir yazimi (distinct)',
       (SELECT COUNT(DISTINCT sehir) FROM dbo.vw_ham_musteri),
       (SELECT COUNT(DISTINCT sehir) FROM dbo.DimMusteri)
UNION ALL SELECT 'Farkli cinsiyet yazimi (distinct)',
       (SELECT COUNT(DISTINCT cinsiyet) FROM dbo.vw_ham_musteri),
       (SELECT COUNT(DISTINCT cinsiyet) FROM dbo.DimMusteri)
UNION ALL SELECT 'Parse edilemeyen / NULL tarih',
       (SELECT SUM(CASE WHEN kayit_tarihi IS NULL OR TRY_CONVERT(date, kayit_tarihi, CASE WHEN kaynak='A' THEN 104 ELSE 111 END) IS NULL THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri),
       (SELECT SUM(CASE WHEN kayit_tarihi IS NULL THEN 1 ELSE 0 END) FROM dbo.DimMusteri)
UNION ALL SELECT 'Duplike email (tekrar eden)',
       (SELECT ISNULL(SUM(tekrar - 1),0) FROM (
            SELECT COUNT(*) AS tekrar FROM dbo.vw_ham_musteri
            WHERE email IS NOT NULL AND LTRIM(RTRIM(email)) <> ''
            GROUP BY LOWER(LTRIM(RTRIM(email))) HAVING COUNT(*) > 1) z),
       (SELECT ISNULL(SUM(tekrar - 1),0) FROM (
            SELECT COUNT(*) AS tekrar FROM dbo.DimMusteri
            WHERE email IS NOT NULL GROUP BY email HAVING COUNT(*) > 1) z2);
GO

/* --- Hedefte standartlasmis sehir dagilimi --- */
PRINT '--- Hedef: standart sehir dagilimi ---';
SELECT ISNULL(sehir, N'(eslesmedi)') AS Sehir, COUNT(*) AS Adet
FROM dbo.DimMusteri GROUP BY sehir ORDER BY Adet DESC;
GO

/* --- Hedefte cinsiyet dagilimi --- */
PRINT '--- Hedef: cinsiyet dagilimi ---';
SELECT ISNULL(cinsiyet,'(bos)') AS Cinsiyet, COUNT(*) AS Adet
FROM dbo.DimMusteri GROUP BY cinsiyet ORDER BY Adet DESC;
GO

/* --- Veri kalite skoru (% dolu kritik alanlar) --- */
PRINT '--- Hedef: tamlik (completeness) skoru ---';
SELECT
    CAST(100.0 * COUNT(email)    / COUNT(*) AS DECIMAL(5,2)) AS [Email_%dolu],
    CAST(100.0 * COUNT(telefon)  / COUNT(*) AS DECIMAL(5,2)) AS [Telefon_%dolu],
    CAST(100.0 * COUNT(sehir)    / COUNT(*) AS DECIMAL(5,2)) AS [Sehir_%dolu],
    CAST(100.0 * COUNT(kayit_tarihi) / COUNT(*) AS DECIMAL(5,2)) AS [Tarih_%dolu]
FROM dbo.DimMusteri;
GO

PRINT '== 05_quality_report.sql TAMAMLANDI ==';
GO
