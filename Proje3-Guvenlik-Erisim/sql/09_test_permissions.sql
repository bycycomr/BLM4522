/* ============================================================================
   Proje 3 - Adım 09: Yetki Testleri (EXECUTE AS)
   ----------------------------------------------------------------------------
   Amaç : Farklı kullanıcıların beklenen şekilde kısıtlanıp kısıtlanmadığını
          tek bir oturumda (sa olarak bağlı) test etmek.
   Yöntem: EXECUTE AS USER = '...' ile impersonation.
   ============================================================================ */

USE PersonelDB;
GO

-- ============================================================================
PRINT N'==== TEST 1: ik_okuyucu (maskelenmiş görüntü + tablo ERİŞİMİ YASAK) ====';
EXECUTE AS USER = N'ik_okuyucu';
PRINT N'--- vw_PersonelIK (maskelenmiş TC) ---';
SELECT TOP (3) Ad, Soyad, TCMaskeli FROM dbo.vw_PersonelIK;

PRINT N'--- Direkt Personel tablosu (DENY olmalı) ---';
BEGIN TRY
    SELECT TOP (1) * FROM dbo.Personel;
END TRY
BEGIN CATCH
    PRINT N'Beklenen hata: ' + ERROR_MESSAGE();
END CATCH
REVERT;

-- ============================================================================
PRINT N'==== TEST 2: muh_yazar (Maas view OK, TC DENY, INSERT personel YASAK) ====';
EXECUTE AS USER = N'muh_yazar';
PRINT N'--- vw_PersonelMaas ---';
SELECT TOP (3) Ad, Soyad, Maas FROM dbo.vw_PersonelMaas;

PRINT N'--- TCKimlikNo doğrudan okumaya çalış (DENY) ---';
BEGIN TRY
    SELECT TOP (1) TCKimlikNo FROM dbo.Personel;
END TRY
BEGIN CATCH
    PRINT N'Beklenen hata: ' + ERROR_MESSAGE();
END CATCH

PRINT N'--- INSERT dene (yetki yok) ---';
BEGIN TRY
    INSERT INTO dbo.Personel (TCKimlikNo, Ad, Soyad, Email, Maas, IseBaslamaTarihi, DepartmanID)
    VALUES (N'99999999999', N'Test', N'User', N't@t.com', 1, GETDATE(), 1);
END TRY
BEGIN CATCH
    PRINT N'Beklenen hata: ' + ERROR_MESSAGE();
END CATCH

PRINT N'--- Maas UPDATE dene (izinli) ---';
BEGIN TRY
    UPDATE dbo.vw_PersonelMaas SET Maas = Maas * 1.05 WHERE PersonelID = 1;
    PRINT N'UPDATE başarılı (maaş %5 zamlandı).';
END TRY
BEGIN CATCH
    PRINT N'Hata: ' + ERROR_MESSAGE();
END CATCH
REVERT;

-- ============================================================================
PRINT N'==== TEST 3: yazilim_sef (RLS: sadece DepartmanID=2) ====';
EXECUTE AS USER = N'yazilim_sef';
PRINT N'--- Personel tablosu (RLS filtre uygulanmalı) ---';
SELECT PersonelID, Ad, Soyad, DepartmanID FROM dbo.Personel;
REVERT;

PRINT N'==== TEST 4: sa (tüm satırları görmeli) ====';
SELECT COUNT(*) AS ToplamSatir FROM dbo.Personel;
GO
