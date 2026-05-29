/* ============================================================================
   BLM4522 - Proje 5: Veri Temizleme ve ETL
   ----------------------------------------------------------------------------
   03_transform_clean.sql
   Amac : Ham veriyi TEMIZLE (cleansing) ve STANDARTLASTIR (transform).
   Adimlar:
     - ad/soyad : TRIM + "Proper Case"
     - email    : TRIM + LOWER + format dogrulama (gecersizse NULL)
     - telefon  : rakam disi karakterleri soy -> son 10 hane -> '+90##########'
     - sehir    : tutarsiz yazimlari tek standarda esle (Istanbul, Ankara, ...)
     - cinsiyet : 'E'/'erkek'/'Erkek' -> 'Erkek' ; 'K'/'kadin' -> 'Kadin'
     - tarih    : kaynaga gore TRY_CONVERT (A=104 GG.AA.YYYY, B=111 YYYY/AA/GG)
     - DEDUP    : normalize email'e gore tekrarlari ele (ROW_NUMBER)
   Sonuc: dbo.temiz_musteri (temizlenmis + tekillestirilmis)
   Calistirma: sqlcmd -S . -E -C -I -b -i 03_transform_clean.sql
   ============================================================================ */
SET NOCOUNT ON;
USE TemizlemeDB;
GO

IF OBJECT_ID('dbo.temiz_musteri','U') IS NOT NULL DROP TABLE dbo.temiz_musteri;
GO
CREATE TABLE dbo.temiz_musteri (
    temiz_id      INT IDENTITY(1,1) PRIMARY KEY,
    ad            NVARCHAR(120) NULL,
    soyad         NVARCHAR(120) NULL,
    email         NVARCHAR(200) NULL,   -- gecersizse NULL
    telefon       NVARCHAR(20)  NULL,   -- '+90##########'
    sehir         NVARCHAR(40)  NULL,
    cinsiyet      VARCHAR(10)   NULL,   -- 'Erkek'/'Kadin'
    kayit_tarihi  DATE          NULL,
    kaynak        CHAR(1)       NOT NULL,
    kaynak_id     INT           NOT NULL
);
GO

/* --- Temizleme + standardizasyon + dedup tek sorguda --- */
;WITH temiz AS (
    SELECT
        kaynak, kaynak_id,
        -- ad/soyad: TRIM + Proper Case (tek kelime adlar icin)
        CASE WHEN LTRIM(RTRIM(ad)) = '' OR ad IS NULL THEN NULL
             ELSE CONCAT(UPPER(LEFT(LTRIM(RTRIM(ad)),1)),
                         LOWER(SUBSTRING(LTRIM(RTRIM(ad)),2,200))) END AS ad,
        CASE WHEN LTRIM(RTRIM(soyad)) = '' OR soyad IS NULL THEN NULL
             ELSE CONCAT(UPPER(LEFT(LTRIM(RTRIM(soyad)),1)),
                         LOWER(SUBSTRING(LTRIM(RTRIM(soyad)),2,200))) END AS soyad,
        -- email: trim+lower; gecersizse NULL
        CASE WHEN email IS NULL THEN NULL
             WHEN LOWER(LTRIM(RTRIM(email))) LIKE '%_@_%._%'
                  AND LOWER(LTRIM(RTRIM(email))) NOT LIKE '% %'
             THEN LOWER(LTRIM(RTRIM(email)))
             ELSE NULL END AS email,
        -- telefon: rakam disi karakterleri soy (+ - ( ) bosluk .) -> son 10 hane
        CASE WHEN telefon IS NULL THEN NULL
             ELSE (
                SELECT CASE WHEN LEN(d) >= 10 THEN CONCAT('+90', RIGHT(d,10)) ELSE NULL END
                FROM (SELECT REPLACE(TRANSLATE(telefon, '+-(). ', '######'), '#', '') AS d) x
             ) END AS telefon,
        -- sehir: tek standarda esle (prefix LIKE ile)
        CASE
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'IST%' THEN N'Istanbul'
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'ANK%' THEN N'Ankara'
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'IZM%' THEN N'Izmir'
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'BUR%' THEN N'Bursa'
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'ANT%' THEN N'Antalya'
            WHEN UPPER(LTRIM(RTRIM(sehir))) LIKE 'ADA%' THEN N'Adana'
            ELSE NULL END AS sehir,
        -- cinsiyet: ilk harfe gore standartlastir
        CASE UPPER(LEFT(LTRIM(RTRIM(cinsiyet)),1))
             WHEN 'E' THEN 'Erkek' WHEN 'K' THEN 'Kadin' ELSE NULL END AS cinsiyet,
        -- tarih: kaynaga gore dogru style ile parse (gecersiz -> NULL)
        TRY_CONVERT(date, kayit_tarihi, CASE WHEN kaynak = 'A' THEN 104 ELSE 111 END) AS kayit_tarihi,
        -- dedup anahtari: gecerli email normalize; yoksa benzersiz fallback
        COALESCE(
            NULLIF(
              CASE WHEN LOWER(LTRIM(RTRIM(email))) LIKE '%_@_%._%'
                        AND LOWER(LTRIM(RTRIM(email))) NOT LIKE '% %'
                   THEN LOWER(LTRIM(RTRIM(email))) END, ''),
            CONCAT('NOEMAIL_', kaynak, '_', kaynak_id)) AS dedup_key
    FROM dbo.vw_ham_musteri
),
sirali AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dedup_key ORDER BY kaynak, kaynak_id) AS rn
    FROM temiz
)
INSERT INTO dbo.temiz_musteri (ad, soyad, email, telefon, sehir, cinsiyet, kayit_tarihi, kaynak, kaynak_id)
SELECT ad, soyad, email, telefon, sehir, cinsiyet, kayit_tarihi, kaynak, kaynak_id
FROM sirali
WHERE rn = 1;   -- her dedup anahtarindan tek kayit
GO

DECLARE @ham INT = (SELECT COUNT(*) FROM dbo.vw_ham_musteri);
DECLARE @temiz INT = (SELECT COUNT(*) FROM dbo.temiz_musteri);
PRINT CONCAT('Ham: ', @ham, ' -> Temiz (dedup sonrasi): ', @temiz, ' | Elenen duplike: ', @ham - @temiz);
GO

PRINT '--- Temizlenmis veriden ornek (ilk 10) ---';
SELECT TOP 10 temiz_id, ad, soyad, email, telefon, sehir, cinsiyet, kayit_tarihi, kaynak
FROM dbo.temiz_musteri ORDER BY temiz_id;
GO

PRINT '== 03_transform_clean.sql TAMAMLANDI ==';
GO
