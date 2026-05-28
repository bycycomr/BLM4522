/* ============================================================================
   BLM4522 - Proje 1: Veritabani Performans Optimizasyonu ve Izleme
   ----------------------------------------------------------------------------
   01_setup_database.sql
   Amac : "Buyuk veritabani" simulasyonu. Bir e-ticaret satis semasi olusturur
          ve ~270.000 satir ornek veri uretir (laptopta saniyeler icinde).
   Onemli: Sema KASTEN sub-optimal kurulur (sadece PK'lar + birkac GEREKSIZ
          indeks). Boylece sonraki adimlar (baseline -> DMV -> indeksleme ->
          gereksiz indeks temizligi -> bakim) gercek bir iyilestirme yapar.
   Calistirma: sqlcmd -S . -E -C -I -b -i 01_setup_database.sql
   ============================================================================ */
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   1) Veritabanini sifirdan olustur (re-runnable)
   --------------------------------------------------------------------------- */
USE master;
GO
IF DB_ID(N'SatisDB') IS NOT NULL
BEGIN
    ALTER DATABASE SatisDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SatisDB;
END
GO
CREATE DATABASE SatisDB;
GO
-- Bulk insert sirasinda log siserini engellemek icin SIMPLE recovery.
ALTER DATABASE SatisDB SET RECOVERY SIMPLE;
GO
-- Veri/log dosyalarina makul bir baslangic boyutu ve buyume adimi ver
-- (otomatik %10 buyume yerine sabit MB => daha az fragmentasyon).
ALTER DATABASE SatisDB
    MODIFY FILE (NAME = N'SatisDB',     SIZE = 200MB, FILEGROWTH = 64MB);
ALTER DATABASE SatisDB
    MODIFY FILE (NAME = N'SatisDB_log', SIZE = 64MB,  FILEGROWTH = 32MB);
GO

USE SatisDB;
GO

/* ---------------------------------------------------------------------------
   2) Tablolar
   Tasarim notu: Tum tablolarda yalnizca PRIMARY KEY (clustered) var.
   Sorgularda kullanilacak filtre/join sutunlarinda (MusteriID, UrunID,
   SiparisTarihi, Sehir ...) BILINCLI olarak indeks YOK -> baseline'da
   table/clustered-index scan gormek icin.
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.Kategori (
    KategoriID   INT           NOT NULL CONSTRAINT PK_Kategori PRIMARY KEY,
    KategoriAdi  NVARCHAR(60)  NOT NULL
);

CREATE TABLE dbo.Urun (
    UrunID       INT            NOT NULL CONSTRAINT PK_Urun PRIMARY KEY,
    UrunAdi      NVARCHAR(120)  NOT NULL,
    KategoriID   INT            NOT NULL,
    BirimFiyat   DECIMAL(10,2)  NOT NULL,
    StokAdedi    INT            NOT NULL
);

CREATE TABLE dbo.Musteri (
    MusteriID    INT            NOT NULL CONSTRAINT PK_Musteri PRIMARY KEY,
    Ad           NVARCHAR(50)   NOT NULL,
    Soyad        NVARCHAR(50)   NOT NULL,
    Email        NVARCHAR(120)  NOT NULL,
    Sehir        NVARCHAR(40)   NOT NULL,
    KayitTarihi  DATE           NOT NULL
);

CREATE TABLE dbo.Siparis (
    SiparisID     INT          NOT NULL CONSTRAINT PK_Siparis PRIMARY KEY,
    MusteriID     INT          NOT NULL,
    SiparisTarihi DATETIME2(0) NOT NULL,
    Durum         VARCHAR(15)  NOT NULL   -- 'Yeni','Hazirlaniyor','Kargoda','Teslim','Iptal'
);

CREATE TABLE dbo.SiparisDetay (
    DetayID      BIGINT        NOT NULL CONSTRAINT PK_SiparisDetay PRIMARY KEY,
    SiparisID    INT           NOT NULL,
    UrunID       INT           NOT NULL,
    Adet         INT           NOT NULL,
    BirimFiyat   DECIMAL(10,2) NOT NULL
);
GO

/* ---------------------------------------------------------------------------
   3) Referans veriler: Kategori (20) ve Urun (2.000)
   --------------------------------------------------------------------------- */
INSERT INTO dbo.Kategori (KategoriID, KategoriAdi)
VALUES (1,N'Elektronik'),(2,N'Bilgisayar'),(3,N'Telefon'),(4,N'Beyaz Esya'),
       (5,N'Mobilya'),(6,N'Kitap'),(7,N'Oyuncak'),(8,N'Giyim'),
       (9,N'Ayakkabi'),(10,N'Kozmetik'),(11,N'Spor'),(12,N'Bahce'),
       (13,N'Otomotiv'),(14,N'Market'),(15,N'Bebek'),(16,N'Evcil Hayvan'),
       (17,N'Muzik'),(18,N'Film'),(19,N'Hobi'),(20,N'Kirtasiye');
GO

-- Tally (sayi) uretici: 10^6'ya kadar satir uretebilen tekrar kullanilabilir CTE.
-- (sys.all_objects'e bagimli kalmadan deterministik calisir.)
DECLARE @UrunSayisi INT = 500;
;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (
    SELECT TOP (@UrunSayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM N a, N b, N c, N d            -- 10^4 yeterli
 )
INSERT INTO dbo.Urun (UrunID, UrunAdi, KategoriID, BirimFiyat, StokAdedi)
SELECT rn,
       CONCAT(N'Urun-', rn),
       (rn % 20) + 1,
       CAST( (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 500000) / 100.0 + 5 AS DECIMAL(10,2)),  -- 5.00 - 5005.00
       ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 1000
FROM Nums;
GO
DECLARE @nUrun INT = (SELECT COUNT(*) FROM dbo.Urun); PRINT CONCAT('Urun satir: ', @nUrun);
GO

/* ---------------------------------------------------------------------------
   4) Musteri (100.000)
   --------------------------------------------------------------------------- */
DECLARE @MusteriSayisi INT = 20000;

;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (
    SELECT TOP (@MusteriSayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM N a, N b, N c, N d, N e       -- 10^5
 )
INSERT INTO dbo.Musteri (MusteriID, Ad, Soyad, Email, Sehir, KayitTarihi)
SELECT rn,
       CONCAT(N'Ad', rn % 5000),
       CONCAT(N'Soyad', rn % 8000),
       CONCAT(N'musteri', rn, N'@ornekmail.com'),
       CASE (rn % 10)   -- deterministik sehir dagitimi (her sehir ~%10)
            WHEN 0 THEN N'Istanbul' WHEN 1 THEN N'Ankara'    WHEN 2 THEN N'Izmir'
            WHEN 3 THEN N'Bursa'    WHEN 4 THEN N'Antalya'   WHEN 5 THEN N'Adana'
            WHEN 6 THEN N'Konya'    WHEN 7 THEN N'Gaziantep' WHEN 8 THEN N'Kayseri'
            ELSE N'Eskisehir' END,
       DATEADD(DAY, -(ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 1825), CAST('2025-12-31' AS DATE))  -- son 5 yil
FROM Nums;
GO
DECLARE @nMusteri INT = (SELECT COUNT(*) FROM dbo.Musteri); PRINT CONCAT('Musteri satir: ', @nMusteri);
GO

/* ---------------------------------------------------------------------------
   5) Siparis (300.000)
   --------------------------------------------------------------------------- */
DECLARE @SiparisSayisi INT = 50000;
DECLARE @MusteriMax INT = (SELECT COUNT(*) FROM dbo.Musteri);

;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (
    SELECT TOP (@SiparisSayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM N a, N b, N c, N d, N e, N f  -- 10^6 kapasite
 )
INSERT INTO dbo.Siparis (SiparisID, MusteriID, SiparisTarihi, Durum)
SELECT rn,
       (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % @MusteriMax) + 1,
       DATEADD(MINUTE, -(ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 1051200), CAST('2025-12-31' AS DATETIME2(0))), -- son ~2 yil
       CASE (rn % 5)    -- deterministik durum dagitimi (her durum %20)
            WHEN 0 THEN 'Yeni' WHEN 1 THEN 'Hazirlaniyor' WHEN 2 THEN 'Kargoda'
            WHEN 3 THEN 'Teslim' ELSE 'Iptal' END
FROM Nums;
GO
DECLARE @nSiparis INT = (SELECT COUNT(*) FROM dbo.Siparis); PRINT CONCAT('Siparis satir: ', @nSiparis);
GO

/* ---------------------------------------------------------------------------
   6) SiparisDetay (1.000.000) - en buyuk tablo
   --------------------------------------------------------------------------- */
DECLARE @DetaySayisi INT = 200000;
DECLARE @SiparisMax INT = (SELECT COUNT(*) FROM dbo.Siparis);
DECLARE @UrunMax    INT = (SELECT COUNT(*) FROM dbo.Urun);

;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (
    SELECT TOP (@DetaySayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM N a, N b, N c, N d, N e, N f  -- 10^6
 )
INSERT INTO dbo.SiparisDetay (DetayID, SiparisID, UrunID, Adet, BirimFiyat)
SELECT rn,
       (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % @SiparisMax) + 1,
       (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % @UrunMax) + 1,
       (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 5) + 1,
       CAST( (ABS(CONVERT(BIGINT, CHECKSUM(NEWID()))) % 500000) / 100.0 + 5 AS DECIMAL(10,2))
FROM Nums;
GO
DECLARE @nDetay INT = (SELECT COUNT(*) FROM dbo.SiparisDetay); PRINT CONCAT('SiparisDetay satir: ', @nDetay);
GO

/* ---------------------------------------------------------------------------
   7) GEREKSIZ / GERIYE DONUK SILINECEK INDEKSLER
   Bu indeksler is yukunde HIC kullanilmayacak. 05_remove_unused_indexes.sql
   bunlari dm_db_index_usage_stats ile tespit edip dusurecek.
     - IX_Musteri_Soyad        : workload Soyad'a gore filtrelemiyor -> olu indeks
     - IX_Urun_StokAdedi       : raporlarda kullanilmiyor -> olu indeks
     - IX_Musteri_Email_dup    : Email zaten essiz; ayni anahtarda 2. indeks -> duplike
   --------------------------------------------------------------------------- */
CREATE INDEX IX_Musteri_Soyad      ON dbo.Musteri(Soyad);
CREATE INDEX IX_Urun_StokAdedi     ON dbo.Urun(StokAdedi);
CREATE INDEX IX_Musteri_Email      ON dbo.Musteri(Email);
CREATE INDEX IX_Musteri_Email_dup  ON dbo.Musteri(Email) INCLUDE (Ad);  -- IX_Musteri_Email ile cakisan duplike
GO

/* ---------------------------------------------------------------------------
   8) Ozet
   --------------------------------------------------------------------------- */
SELECT  t.name AS Tablo,
        SUM(p.rows) AS [Satir Sayisi],
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(10,2)) AS [Toplam MB]
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
JOIN sys.allocation_units a ON a.container_id = p.partition_id
GROUP BY t.name
ORDER BY SUM(p.rows) DESC;
GO
PRINT '== 01_setup_database.sql TAMAMLANDI ==';
GO
