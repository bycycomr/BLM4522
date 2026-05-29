/* ============================================================================
   BLM4522 - Proje 5: Veri Temizleme ve ETL
   ----------------------------------------------------------------------------
   02_data_profiling.sql
   Amac : Temizlik ONCESI veri kalitesini olcer (data profiling). Bu sayilar
          05_quality_report.sql'deki "sonra" degerleriyle karsilastirilacaktir.
   Once iki kaynagi tek bir ham gorunumde (vw_ham_musteri) birlestirir.
   Calistirma: sqlcmd -S . -E -C -I -b -i 02_data_profiling.sql
   ============================================================================ */
SET NOCOUNT ON;
USE TemizlemeDB;
GO

/* --- Iki kaynagi birlestiren ham gorunum (sonraki adimlar da kullanir) --- */
CREATE OR ALTER VIEW dbo.vw_ham_musteri AS
    SELECT 'A' AS kaynak, kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet
    FROM dbo.stg_kaynakA
    UNION ALL
    SELECT 'B', kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet
    FROM dbo.stg_kaynakB;
GO

/* --- Veri kalitesi metrikleri (tek sonuc kumesi) --- */
PRINT '--- TEMIZLIK ONCESI VERI KALITESI ---';
SELECT 'Toplam ham satir' AS Metrik, COUNT(*) AS Deger FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Email NULL/bos',
    SUM(CASE WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Email gecersiz (format)',
    SUM(CASE WHEN email IS NOT NULL AND (email LIKE '% %' OR email NOT LIKE '%_@_%._%') THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Ad NULL',
    SUM(CASE WHEN ad IS NULL THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Ad bas/son bosluklu',
    SUM(CASE WHEN ad IS NOT NULL AND ad <> LTRIM(RTRIM(ad)) THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Telefon NULL',
    SUM(CASE WHEN telefon IS NULL THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Tarih parse edilemiyor',
    SUM(CASE WHEN TRY_CONVERT(date, kayit_tarihi, CASE WHEN kaynak='A' THEN 104 ELSE 111 END) IS NULL
                  AND kayit_tarihi IS NOT NULL THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Tarih NULL',
    SUM(CASE WHEN kayit_tarihi IS NULL THEN 1 ELSE 0 END) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Farkli sehir yazimi (distinct)',
    COUNT(DISTINCT sehir) FROM dbo.vw_ham_musteri
UNION ALL SELECT 'Farkli cinsiyet yazimi (distinct)',
    COUNT(DISTINCT cinsiyet) FROM dbo.vw_ham_musteri;
GO

/* --- Duplike email analizi (normalize edilmis: trim + lower) --- */
PRINT '--- Duplike email (trim+lower sonrasi ayni olanlar) ---';
SELECT LOWER(LTRIM(RTRIM(email))) AS email_norm, COUNT(*) AS tekrar
FROM   dbo.vw_ham_musteri
WHERE  email IS NOT NULL AND LTRIM(RTRIM(email)) <> ''
GROUP BY LOWER(LTRIM(RTRIM(email)))
HAVING COUNT(*) > 1
ORDER BY tekrar DESC, email_norm;
GO

/* --- Tutarsiz sehir yazimlarinin ornegi --- */
PRINT '--- Ham sehir degerleri (tutarsizlik) ---';
SELECT sehir AS HamSehir, COUNT(*) AS Adet
FROM   dbo.vw_ham_musteri
GROUP BY sehir
ORDER BY Adet DESC;
GO

PRINT '== 02_data_profiling.sql TAMAMLANDI ==';
GO
