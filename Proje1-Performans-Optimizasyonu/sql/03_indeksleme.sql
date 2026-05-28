/* ============================================================================
   BLM4522 - Proje 1: Veritabani Performans Optimizasyonu ve Izleme
   ----------------------------------------------------------------------------
   03_indeksleme.sql
   Gereksinim 4 : Dogru indeksleri olusturmak + gereksiz indeksleri kaldirmak.
   Mantik:
     A) 02'deki "eksik indeks" onerilerine gore DOGRU indeksleri olustur.
     B) Ayni baseline sorguyu tekrar olc -> scan'den seek'e gecisi goster.
     C) Hic okunmayan (olu) ve duplike indeksleri DUSUR.
   Calistirma: sqlcmd -S . -E -C -I -b -i 03_indeksleme.sql
   ============================================================================ */
SET NOCOUNT ON;
USE SatisDB;
GO

/* ===========================================================================
   A) DOGRU INDEKSLER
   - FK/join sutunlari: Siparis.MusteriID, SiparisDetay.SiparisID
   - Filtre sutunu     : Musteri.Sehir  (+ INCLUDE ile covering)
   - Tarih araligi     : Siparis.SiparisTarihi
   =========================================================================== */
PRINT '--- Indeksler olusturuluyor ---';

-- 1) Join: Siparis -> Musteri
CREATE NONCLUSTERED INDEX IX_Siparis_MusteriID
    ON dbo.Siparis (MusteriID)
    INCLUDE (SiparisTarihi, Durum);

-- 2) Tarih araligi filtreleri icin
CREATE NONCLUSTERED INDEX IX_Siparis_Tarih
    ON dbo.Siparis (SiparisTarihi)
    INCLUDE (MusteriID);

-- 3) Join: SiparisDetay -> Siparis  (covering: Adet, BirimFiyat dahil)
CREATE NONCLUSTERED INDEX IX_SiparisDetay_SiparisID
    ON dbo.SiparisDetay (SiparisID)
    INCLUDE (Adet, BirimFiyat);

-- 4) Filtre: Musteri.Sehir  (covering)
CREATE NONCLUSTERED INDEX IX_Musteri_Sehir
    ON dbo.Musteri (Sehir)
    INCLUDE (Ad, Soyad);

-- 5) FILTRELI (filtered) INDEKS ornegi: yalniz aktif (Iptal olmayan) siparisler.
--    Tum tabloyu indekslemekten daha kucuk ve hizli. (IN, filtered index'te
--    kesin desteklenen bir yuklemdir; "<>" yerine pozitif liste kullanildi.)
CREATE NONCLUSTERED INDEX IX_Siparis_Aktif
    ON dbo.Siparis (MusteriID)
    WHERE Durum IN ('Yeni','Hazirlaniyor','Kargoda','Teslim');
GO

/* ===========================================================================
   B) AFTER: Ayni baseline sorgu tekrar olculuyor
   02'deki "logical reads" ile karsilastir -> belirgin dusus beklenir.
   =========================================================================== */
PRINT '--- AFTER (indeks SONRASI) ---';
DBCC DROPCLEANBUFFERS;
SET STATISTICS IO  ON;
SET STATISTICS TIME ON;

SELECT  m.Sehir,
        COUNT(DISTINCT s.SiparisID)  AS SiparisSayisi,
        SUM(sd.Adet * sd.BirimFiyat) AS ToplamCiro
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

/* ===========================================================================
   C) GEREKSIZ / DUPLIKE INDEKSLERIN KALDIRILMASI
   =========================================================================== */

-- C.1) Duplike indeks tespiti: ayni tablo + ayni anahtar sutun(lar).
PRINT '--- Duplike indeks adaylari ---';
WITH ix AS (
    SELECT i.object_id, i.index_id, i.name,
           STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS anahtar
    FROM       sys.indexes i
    JOIN       sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
    JOIN       sys.columns c        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE  i.type_desc = 'NONCLUSTERED'
    GROUP BY i.object_id, i.index_id, i.name
)
SELECT OBJECT_NAME(a.object_id) AS Tablo, a.name AS Indeks1, b.name AS Indeks2, a.anahtar AS OrtakAnahtar
FROM ix a JOIN ix b ON a.object_id = b.object_id AND a.anahtar = b.anahtar AND a.index_id < b.index_id;
GO

-- C.2) Hic okunmayan (olu) indeksler: seek+scan+lookup = 0
PRINT '--- Olu (hic okunmayan) indeks adaylari ---';
SELECT OBJECT_NAME(i.object_id) AS Tablo, i.name AS Indeks,
       ISNULL(us.user_seeks,0)+ISNULL(us.user_scans,0)+ISNULL(us.user_lookups,0) AS ToplamOkuma,
       ISNULL(us.user_updates,0) AS Guncelleme
FROM       sys.indexes i
LEFT JOIN  sys.dm_db_index_usage_stats us
       ON  us.object_id = i.object_id AND us.index_id = i.index_id AND us.database_id = DB_ID()
WHERE  i.type_desc = 'NONCLUSTERED'
  AND  (ISNULL(us.user_seeks,0)+ISNULL(us.user_scans,0)+ISNULL(us.user_lookups,0)) = 0
ORDER BY Tablo, Indeks;
GO

-- C.3) Tespit edilen gereksiz indeksleri DUSUR
--      (01'de bilincli olarak eklenmislerdi: hicbiri is yukunde kullanilmiyor)
PRINT '--- Gereksiz indeksler dusuruluyor ---';
DROP INDEX IF EXISTS IX_Musteri_Soyad     ON dbo.Musteri;   -- olu: Soyad'a gore filtre yok
DROP INDEX IF EXISTS IX_Urun_StokAdedi    ON dbo.Urun;      -- olu: raporlarda kullanilmiyor
DROP INDEX IF EXISTS IX_Musteri_Email_dup ON dbo.Musteri;   -- duplike: IX_Musteri_Email yeterli
GO

PRINT '== 03_indeksleme.sql TAMAMLANDI ==';
GO
