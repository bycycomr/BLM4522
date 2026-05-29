/* ============================================================================
   BLM4522 - Proje 5: Veri Temizleme ve ETL
   ----------------------------------------------------------------------------
   04_load_target.sql
   Amac : Temizlenmis/tekillestirilmis veriyi HEDEF tabloya (DimMusteri) yukle.
   Yontem: MERGE (UPSERT) -> yeni kayit INSERT, mevcut kayit UPDATE.
           Is anahtari (business key): email; email yoksa 'NOEMAIL:kaynak_id'.
           MERGE sayesinde script tekrar calistirildiginda DUPLIKE OLUSMAZ
           (idempotent yukleme).
   Calistirma: sqlcmd -S . -E -C -I -b -i 04_load_target.sql
   ============================================================================ */
SET NOCOUNT ON;
USE TemizlemeDB;
GO

/* --- Hedef tablo (yoksa olustur; varsa korunur -> idempotent test edilebilir) --- */
IF OBJECT_ID('dbo.DimMusteri','U') IS NULL
BEGIN
    CREATE TABLE dbo.DimMusteri (
        musteri_key       INT IDENTITY(1,1) PRIMARY KEY,   -- surrogate key
        is_anahtar        NVARCHAR(210) NOT NULL UNIQUE,    -- business key
        ad                NVARCHAR(120) NULL,
        soyad             NVARCHAR(120) NULL,
        email             NVARCHAR(200) NULL,
        telefon           NVARCHAR(20)  NULL,
        sehir             NVARCHAR(40)  NULL,
        cinsiyet          VARCHAR(10)   NULL,
        kayit_tarihi      DATE          NULL,
        kaynak            CHAR(1)       NOT NULL,
        kaynak_id         INT           NOT NULL,
        yuklenme_tarihi   DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
        guncelleme_tarihi DATETIME2(0)  NULL
    );
END
GO

/* --- MERGE ile yukleme --- */
MERGE dbo.DimMusteri AS hedef
USING (
    SELECT *,
           COALESCE(email, CONCAT('NOEMAIL:', kaynak, '_', kaynak_id)) AS is_anahtar
    FROM dbo.temiz_musteri
) AS src
ON hedef.is_anahtar = src.is_anahtar
WHEN MATCHED AND (
        ISNULL(hedef.telefon,'') <> ISNULL(src.telefon,'')
     OR ISNULL(hedef.sehir,'')   <> ISNULL(src.sehir,'')
     OR ISNULL(hedef.cinsiyet,'')<> ISNULL(src.cinsiyet,'')
   ) THEN UPDATE SET
        hedef.ad = src.ad, hedef.soyad = src.soyad,
        hedef.telefon = src.telefon, hedef.sehir = src.sehir,
        hedef.cinsiyet = src.cinsiyet, hedef.kayit_tarihi = src.kayit_tarihi,
        hedef.guncelleme_tarihi = SYSDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (is_anahtar, ad, soyad, email, telefon, sehir, cinsiyet, kayit_tarihi, kaynak, kaynak_id)
    VALUES (src.is_anahtar, src.ad, src.soyad, src.email, src.telefon, src.sehir,
            src.cinsiyet, src.kayit_tarihi, src.kaynak, src.kaynak_id);
GO

DECLARE @hedef INT = (SELECT COUNT(*) FROM dbo.DimMusteri);
DECLARE @temiz INT = (SELECT COUNT(*) FROM dbo.temiz_musteri);
PRINT CONCAT('Hedef DimMusteri satir: ', @hedef, ' (temiz kaynak: ', @temiz, ')');
GO

PRINT '--- Hedef tablodan ornek (ilk 10) ---';
SELECT TOP 10 musteri_key, ad, soyad, email, telefon, sehir, cinsiyet, kayit_tarihi, kaynak
FROM dbo.DimMusteri ORDER BY musteri_key;
GO

PRINT '== 04_load_target.sql TAMAMLANDI ==';
GO
