/* ============================================================================
   BLM4522 - Proje 5: Veri Temizleme ve ETL Surecleri Tasarimi
   ----------------------------------------------------------------------------
   01_setup_raw_data.sql
   Amac : Iki FARKLI kaynaktan (Kaynak A ve Kaynak B) gelmis gibi tasarlanmis,
          KASTEN KIRLI bir 'ham veri' (staging) kumesi olusturur.
   Kirlilik tipleri: bosluk (trim), buyuk/kucuk harf tutarsizligi, gecersiz
          email, farkli telefon formatlari, string tarih (farkli formatlar),
          tutarsiz sehir yazimlari, NULL/bos, ve DUPLIKE kayitlar.
   Not  : sqlcmd kodlama sorunlarini onlemek icin SQL icinde ASCII kullanildi.
   Calistirma: sqlcmd -S . -E -C -I -b -i 01_setup_raw_data.sql
   ============================================================================ */
SET NOCOUNT ON;
GO
USE master;
GO
IF DB_ID(N'TemizlemeDB') IS NOT NULL
BEGIN
    ALTER DATABASE TemizlemeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TemizlemeDB;
END
GO
CREATE DATABASE TemizlemeDB;
GO
ALTER DATABASE TemizlemeDB SET RECOVERY SIMPLE;
GO
USE TemizlemeDB;
GO

/* ---------------------------------------------------------------------------
   1) Staging tablolari (her sutun ham/serbest metin -> veri kirli gelir)
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.stg_kaynakA (
    kaynak_id     INT            NOT NULL,
    ad            NVARCHAR(120)  NULL,
    soyad         NVARCHAR(120)  NULL,
    email         NVARCHAR(200)  NULL,
    telefon       NVARCHAR(60)   NULL,   -- format: '05XX XXX XX XX'
    sehir         NVARCHAR(100)  NULL,
    kayit_tarihi  NVARCHAR(40)   NULL,   -- string, format: 'GG.AA.YYYY'
    cinsiyet      NVARCHAR(20)   NULL    -- 'Erkek'/'Kadin' (bazen 'E', bazen kucuk)
);

CREATE TABLE dbo.stg_kaynakB (
    kaynak_id     INT            NOT NULL,
    ad            NVARCHAR(120)  NULL,
    soyad         NVARCHAR(120)  NULL,
    email         NVARCHAR(200)  NULL,
    telefon       NVARCHAR(60)   NULL,   -- format: '+90-5XX-XXXXXXX'
    sehir         NVARCHAR(100)  NULL,
    kayit_tarihi  NVARCHAR(40)   NULL,   -- string, format: 'YYYY/AA/GG'
    cinsiyet      NVARCHAR(20)   NULL    -- 'E'/'K'
);
GO

/* ---------------------------------------------------------------------------
   2) KAYNAK A - 1200 satir (deterministik kirlilik, rn'e bagli)
   --------------------------------------------------------------------------- */
DECLARE @ASayisi INT = 1200;
;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (SELECT TOP (@ASayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
          FROM N a, N b, N c, N d)
INSERT INTO dbo.stg_kaynakA (kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet)
SELECT
    rn,
    -- ad: bazi satirlarda bosluklu, buyuk/kucuk harf karisik
    CASE WHEN rn % 4 = 0 THEN CONCAT(N'  ', N'Ad', rn % 200, N'   ')
         WHEN rn % 3 = 0 THEN UPPER(CONCAT(N'Ad', rn % 200))
         WHEN rn % 3 = 1 THEN LOWER(CONCAT(N'Ad', rn % 200))
         ELSE CONCAT(N'Ad', rn % 200) END,
    -- soyad
    CASE WHEN rn % 5 = 0 THEN CONCAT(N' Soyad', rn % 300, N' ')
         WHEN rn % 2 = 0 THEN UPPER(CONCAT(N'Soyad', rn % 300))
         ELSE CONCAT(N'Soyad', rn % 300) END,
    -- email: %13 NULL, %7 gecersiz (@ yok), %4 bosluklu, geri kalan gecerli
    CASE WHEN rn % 13 = 0 THEN NULL
         WHEN rn % 7  = 0 THEN CONCAT(N'musteri', rn, N'#ornek.com')   -- gecersiz
         WHEN rn % 4  = 0 THEN CONCAT(N' musteri', rn, N'@ornek.com ') -- bosluklu
         ELSE CONCAT(N'musteri', rn, N'@ornek.com') END,
    -- telefon: '05XX XXX XX XX' (bazen NULL, bazen parantezli)
    CASE WHEN rn % 9 = 0 THEN NULL
         WHEN rn % 6 = 0 THEN CONCAT(N'(05', RIGHT(CONCAT('0', rn % 100), 2), N') ',
                                     RIGHT(CONCAT('00', rn % 1000), 3), N' ',
                                     RIGHT(CONCAT('0', rn % 100), 2), RIGHT(CONCAT('0', rn % 100), 2))
         ELSE CONCAT(N'05', RIGHT(CONCAT('0', rn % 100), 2), N' ',
                     RIGHT(CONCAT('00', rn % 1000), 3), N' ',
                     RIGHT(CONCAT('0', rn % 100), 2), N' ', RIGHT(CONCAT('0', rn % 100), 2)) END,
    -- sehir: tutarsiz yazim (buyuk/kucuk/kisaltma/bosluk)
    CASE rn % 6
         WHEN 0 THEN N'ISTANBUL'   WHEN 1 THEN N'istanbul'
         WHEN 2 THEN N'Ankara '    WHEN 3 THEN N' izmir'
         WHEN 4 THEN N'BURSA'      ELSE N'Antalya' END,
    -- kayit_tarihi: 'GG.AA.YYYY' string; %15 gecersiz tarih
    CASE WHEN rn % 15 = 0 THEN N'32.13.2020'   -- gecersiz
         ELSE CONCAT(RIGHT(CONCAT('0', (rn % 28) + 1), 2), N'.',
                     RIGHT(CONCAT('0', (rn % 12) + 1), 2), N'.',
                     2018 + (rn % 7)) END,
    -- cinsiyet: 'Erkek'/'Kadin' ama bazen 'E'/'erkek'
    CASE WHEN rn % 8 = 0 THEN N'E'
         WHEN rn % 6 = 0 THEN N'kadin'
         WHEN rn % 2 = 0 THEN N'Erkek' ELSE N'Kadin' END
FROM Nums;
GO

/* ---------------------------------------------------------------------------
   3) KAYNAK B - 800 satir (FARKLI formatlar)
   --------------------------------------------------------------------------- */
DECLARE @BSayisi INT = 800;
;WITH N AS (SELECT n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
 Nums AS (SELECT TOP (@BSayisi) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
          FROM N a, N b, N c, N d)
INSERT INTO dbo.stg_kaynakB (kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet)
SELECT
    10000 + rn,
    CASE WHEN rn % 3 = 0 THEN UPPER(CONCAT(N'Ad', rn % 150)) ELSE CONCAT(N'Ad', rn % 150) END,
    CONCAT(N'Soyad', rn % 250),
    -- email: %10 NULL, %9 bosluklu, geri kalan gecerli (B kaynagi -> '.net')
    CASE WHEN rn % 10 = 0 THEN NULL
         WHEN rn % 9  = 0 THEN CONCAT(N'  user', rn, N'@kaynakb.net')
         ELSE CONCAT(N'user', rn, N'@kaynakb.net') END,
    -- telefon: '+90-5XX-XXXXXXX'
    CASE WHEN rn % 11 = 0 THEN NULL
         ELSE CONCAT(N'+90-5', RIGHT(CONCAT('0', rn % 100), 2), N'-',
                     RIGHT(CONCAT('0000000', rn), 7)) END,
    -- sehir: ulke ekli / kisaltmali
    CASE rn % 5
         WHEN 0 THEN N'Istanbul/TR' WHEN 1 THEN N'ANKARA'
         WHEN 2 THEN N'Izmir'       WHEN 3 THEN N'ist.'
         ELSE N'Bursa' END,
    -- kayit_tarihi: 'YYYY/AA/GG' string
    CONCAT(2015 + (rn % 9), N'/',
           RIGHT(CONCAT('0', (rn % 12) + 1), 2), N'/',
           RIGHT(CONCAT('0', (rn % 28) + 1), 2)),
    -- cinsiyet: 'E'/'K'
    CASE WHEN rn % 2 = 0 THEN N'E' ELSE N'K' END
FROM Nums;
GO

/* ---------------------------------------------------------------------------
   4) Acik DUPLIKE ve uc-durum (edge case) kayitlari
   Ayni email farkli kaynaktan / farkli yazimla tekrar -> dedup demosu.
   --------------------------------------------------------------------------- */
INSERT INTO dbo.stg_kaynakA (kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet) VALUES
 (90001, N'  Ahmet ', N'YILMAZ',  N'ahmet.yilmaz@ornek.com',  N'0532 111 22 33', N'istanbul', N'05.06.2020', N'Erkek'),
 (90002, N'AHMET',    N'Yilmaz',  N' ahmet.yilmaz@ornek.com ',N'0532 111 22 33', N'ISTANBUL', N'05.06.2020', N'erkek'),  -- A icindeki duplike
 (90003, N'Mehmet',   N'Demir',   N'mehmet#demir.com',        N'(0533) 444 5566',N'BURSA',    N'31.02.2021', N'E'),       -- gecersiz email + gecersiz tarih
 (90004, NULL,        N'Kaya',    NULL,                       NULL,             N' izmir',   NULL,          NULL);       -- bol NULL

INSERT INTO dbo.stg_kaynakB (kaynak_id, ad, soyad, email, telefon, sehir, kayit_tarihi, cinsiyet) VALUES
 (99001, N'Ahmet',    N'Yilmaz',  N'AHMET.YILMAZ@ornek.com',  N'+90-532-1112233', N'Istanbul/TR', N'2020/06/05', N'E'),  -- A ile ayni kisi (cross-source duplike)
 (99002, N'Zeynep',   N'Sahin',   N'zeynep@kaynakb.net',      N'+90-505-9998877', N'ANKARA',      N'2019/12/01', N'K');
GO

/* ---------------------------------------------------------------------------
   5) Ozet
   --------------------------------------------------------------------------- */
DECLARE @a INT = (SELECT COUNT(*) FROM dbo.stg_kaynakA);
DECLARE @b INT = (SELECT COUNT(*) FROM dbo.stg_kaynakB);
PRINT CONCAT('Kaynak A satir: ', @a, ' | Kaynak B satir: ', @b);
GO
PRINT '== 01_setup_raw_data.sql TAMAMLANDI ==';
GO
