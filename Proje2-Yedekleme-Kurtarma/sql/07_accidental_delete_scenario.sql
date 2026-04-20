/* ============================================================================
   Proje 2 - Adım 07: Yanlışlıkla Silinen Veri Senaryosu
   ----------------------------------------------------------------------------
   Amaç: Üretimde kritik bir yanlış işlem (ör. WHERE unutulmuş DELETE) olduğunu
         simüle etmek ve PITR ile geri dönmek.
   Adımlar:
      1) FULL backup al (02_full_backup.sql).
      2) İş verisi ekle/güncelle.
      3) LOG backup al (04_log_backup.sql).
      4) Tarihi not al  -> @KotuAnaZamani
      5) Aşağıdaki "YANLIŞ" DELETE'i çalıştır.
      6) 06_restore_point_in_time.sql'i @KotuAnaZamani - 1 saniye olarak koş.
      7) DB kurtarıldı mı diye doğrula.
   ============================================================================ */

USE OkulDB;
GO

PRINT N'--- İşlem öncesi Ogrenci tablosu ---';
SELECT * FROM dbo.Ogrenci;

-- 1) İş verisi
INSERT INTO dbo.Ogrenci (Ad, Soyad, Numara, Bolum) VALUES
 (N'Burak', N'Koç',   N'20200009', N'Bilgisayar Mühendisliği'),
 (N'Deniz', N'Öztürk',N'20200010', N'Bilgisayar Mühendisliği');

DECLARE @OncekiSayi INT = (SELECT COUNT(*) FROM dbo.Ogrenci);
PRINT N'Satır sayısı (kötü işlem öncesi): ' + CAST(@OncekiSayi AS NVARCHAR(10));

-- 2) Bu anı PITR için not et
DECLARE @KotuAnaZamani DATETIME2(0) = SYSDATETIME();
PRINT N'Zaman damgası: ' + CONVERT(NVARCHAR(25), @KotuAnaZamani, 121);

WAITFOR DELAY '00:00:02';

-- 3) YANLIŞ DELETE (WHERE unutulmuş)
DELETE FROM dbo.Ogrenci;  -- !!! felaket

PRINT N'Silme sonrası satır sayısı: ' + CAST((SELECT COUNT(*) FROM dbo.Ogrenci) AS NVARCHAR(10));
PRINT N'PITR komutunda @StopAt olarak şunu kullanın: ' + CONVERT(NVARCHAR(25), @KotuAnaZamani, 126);
GO
