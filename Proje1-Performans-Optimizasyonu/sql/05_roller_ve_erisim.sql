/* ============================================================================
   BLM4522 - Proje 1: Veritabani Performans Optimizasyonu ve Izleme
   ----------------------------------------------------------------------------
   05_roller_ve_erisim.sql
   Gereksinim 6 : Farkli roller icin veritabani erisim yonetimi (RBAC).
   Senaryo - bu performans projesine uygun 3 rol:
     rol_rapor_okuyucu : sadece SELECT (raporlama)
     rol_veri_giris    : SELECT + INSERT/UPDATE (operasyon)
     rol_perf_izleyici : DMV/performans gorebilen ama veriyi DEGISTIREMEYEN izleyici
   En az yetki (least privilege) ilkesi uygulanir.
   Calistirma: sqlcmd -S . -E -C -I -b -i 05_roller_ve_erisim.sql
   ============================================================================ */
SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   1) Sunucu seviyesi login'ler (SQL Auth) - re-runnable
   --------------------------------------------------------------------------- */
USE master;
GO
IF SUSER_ID(N'rapor_user')  IS NOT NULL DROP LOGIN rapor_user;
IF SUSER_ID(N'giris_user')  IS NOT NULL DROP LOGIN giris_user;
IF SUSER_ID(N'izleme_user') IS NOT NULL DROP LOGIN izleme_user;
GO
CREATE LOGIN rapor_user  WITH PASSWORD = 'Rapor#2026!',  CHECK_POLICY = ON;
CREATE LOGIN giris_user  WITH PASSWORD = 'Giris#2026!',  CHECK_POLICY = ON;
CREATE LOGIN izleme_user WITH PASSWORD = 'Izleme#2026!', CHECK_POLICY = ON;
GO

-- "perf_izleyici" sunucu genelinde DMV gorebilmeli -> VIEW SERVER STATE
GRANT VIEW SERVER STATE TO izleme_user;
GO

/* ---------------------------------------------------------------------------
   2) Veritabani kullanicilari ve roller
   --------------------------------------------------------------------------- */
USE SatisDB;
GO
IF USER_ID(N'rapor_user')  IS NOT NULL DROP USER rapor_user;
IF USER_ID(N'giris_user')  IS NOT NULL DROP USER giris_user;
IF USER_ID(N'izleme_user') IS NOT NULL DROP USER izleme_user;
GO
CREATE USER rapor_user  FOR LOGIN rapor_user;
CREATE USER giris_user  FOR LOGIN giris_user;
CREATE USER izleme_user FOR LOGIN izleme_user;
GO

-- Roller (re-runnable)
IF DATABASE_PRINCIPAL_ID(N'rol_rapor_okuyucu') IS NOT NULL DROP ROLE rol_rapor_okuyucu;
IF DATABASE_PRINCIPAL_ID(N'rol_veri_giris')    IS NOT NULL DROP ROLE rol_veri_giris;
IF DATABASE_PRINCIPAL_ID(N'rol_perf_izleyici') IS NOT NULL DROP ROLE rol_perf_izleyici;
GO
CREATE ROLE rol_rapor_okuyucu;
CREATE ROLE rol_veri_giris;
CREATE ROLE rol_perf_izleyici;
GO

/* ---------------------------------------------------------------------------
   3) Yetkiler (least privilege)
   --------------------------------------------------------------------------- */
-- a) Raporlama: tum tablolarda yalniz okuma
GRANT SELECT ON SCHEMA::dbo TO rol_rapor_okuyucu;

-- b) Veri girisi: okuma + yazma (ama DDL / silme yetkisi yok)
GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO rol_veri_giris;

-- c) Performans izleyici: veritabani DMV'lerini gorebilir, veriyi goremez/degistiremez
GRANT VIEW DATABASE STATE TO rol_perf_izleyici;
-- Guvenlik: en buyuk tablonun verisine erisimi acikca engelle (DENY > GRANT)
DENY SELECT ON OBJECT::dbo.SiparisDetay TO rol_perf_izleyici;
GO

-- Kullanicilari rollere ata
ALTER ROLE rol_rapor_okuyucu ADD MEMBER rapor_user;
ALTER ROLE rol_veri_giris    ADD MEMBER giris_user;
ALTER ROLE rol_perf_izleyici ADD MEMBER izleme_user;
GO

/* ---------------------------------------------------------------------------
   4) Test: EXECUTE AS ile rol davranislarini dogrula
   Desen: EXECUTE AS (TRY disinda) -> islem (TRY icinde) -> CATCH -> REVERT.
   Boylece beklenen yetki hatalari yakalanir ve script exit code 0 ile biter
   (yakalanmayan hata, -b bayragiyla calisan runner'i FAIL'e dusururdu).
   --------------------------------------------------------------------------- */
PRINT '--- TEST 1: rapor_user SELECT yapabilmeli ---';
EXECUTE AS USER = 'rapor_user';
    SELECT 'rapor_user SELECT OK' AS Sonuc, COUNT(*) AS MusteriSayisi FROM dbo.Musteri;
REVERT;
GO

PRINT '--- TEST 2: rapor_user INSERT YAPAMAMALI (hata beklenir) ---';
EXECUTE AS USER = 'rapor_user';
BEGIN TRY
    INSERT INTO dbo.Kategori(KategoriID, KategoriAdi) VALUES (999, N'Yetkisiz');
    PRINT 'HATA: rapor_user yazabildi - YANLIS!';
END TRY
BEGIN CATCH
    PRINT 'BEKLENEN: rapor_user INSERT engellendi -> ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

PRINT '--- TEST 3: giris_user INSERT yapabilmeli ---';
EXECUTE AS USER = 'giris_user';
BEGIN TRY
    INSERT INTO dbo.Kategori(KategoriID, KategoriAdi) VALUES (998, N'GirisTest');
    PRINT 'giris_user INSERT OK';
END TRY
BEGIN CATCH
    PRINT 'HATA: giris_user yazamadi -> ' + ERROR_MESSAGE();
END CATCH;
REVERT;
DELETE FROM dbo.Kategori WHERE KategoriID = 998;   -- test satirini admin temizler
GO

PRINT '--- TEST 4: izleme_user SiparisDetay verisini GOREMEMELI (DENY) ---';
EXECUTE AS USER = 'izleme_user';
BEGIN TRY
    SELECT TOP 1 * FROM dbo.SiparisDetay;
    PRINT 'HATA: izleme_user veriyi gordu - YANLIS!';
END TRY
BEGIN CATCH
    PRINT 'BEKLENEN: izleme_user SiparisDetay erisimi engellendi (DENY) -> ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

PRINT '--- rol_perf_izleyici yetkileri (VIEW DATABASE STATE dahil) ---';
SELECT dp.permission_name, dp.state_desc, ISNULL(OBJECT_NAME(dp.major_id),'(veritabani)') AS Nesne
FROM       sys.database_permissions dp
JOIN       sys.database_principals pr ON pr.principal_id = dp.grantee_principal_id
WHERE  pr.name = 'rol_perf_izleyici';
GO

/* ---------------------------------------------------------------------------
   5) Ozet: roller ve uyeleri
   --------------------------------------------------------------------------- */
PRINT '--- Roller ve uyeleri ---';
SELECT r.name AS Rol, m.name AS Uye
FROM       sys.database_role_members rm
JOIN       sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN       sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE  r.name LIKE 'rol_%'
ORDER BY Rol, Uye;
GO

PRINT '== 05_roller_ve_erisim.sql TAMAMLANDI ==';
GO
