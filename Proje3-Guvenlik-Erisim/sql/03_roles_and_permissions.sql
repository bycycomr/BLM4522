/* ============================================================================
   Proje 3 - Adım 03: Rol Tabanlı Erişim Kontrolü (RBAC)
   ----------------------------------------------------------------------------
   Amaç  : "Least privilege" (en az yetki) ilkesini uygulamak. Her kullanıcı,
           yalnızca işini yapmaya yetecek kadar yetkiye sahip olmalıdır.
   Model : Kullanıcılar doğrudan yetki almaz -> rollere atanır, roller
           yetki alır. Bu, yetim yetkilerin birikmesini önler.
   ============================================================================ */

USE PersonelDB;
GO

/* --- Mevcut rolleri temizle --- */
IF DATABASE_PRINCIPAL_ID(N'rol_ik_okuyucu')   IS NOT NULL DROP ROLE rol_ik_okuyucu;
IF DATABASE_PRINCIPAL_ID(N'rol_muhasebe')     IS NOT NULL DROP ROLE rol_muhasebe;
IF DATABASE_PRINCIPAL_ID(N'rol_yazilim_sef')  IS NOT NULL DROP ROLE rol_yazilim_sef;
GO

/* --- Rolleri oluştur --- */
CREATE ROLE rol_ik_okuyucu;     -- sadece okuyabilir, hassas sütunları GÖREMEZ
CREATE ROLE rol_muhasebe;       -- Maas'ı okur/günceller, TC'yi göremez
CREATE ROLE rol_yazilim_sef;    -- kendi departmanını yönetir (bkz. RLS)
GO

/* --------------------------------------------------------------------------
   Hassas sütunları kolonlardan maskelemek için GÜVENLİ VIEW
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.vw_PersonelIK', 'V') IS NOT NULL DROP VIEW dbo.vw_PersonelIK;
GO
CREATE VIEW dbo.vw_PersonelIK AS
    SELECT PersonelID, Ad, Soyad, Email, Telefon,
           -- IK TC'yi tam görmemeli: son 4 hane maskelenir
           CONCAT(LEFT(TCKimlikNo, 3), N'****', RIGHT(TCKimlikNo, 4)) AS TCMaskeli,
           IseBaslamaTarihi, DepartmanID
    FROM dbo.Personel;
GO

IF OBJECT_ID(N'dbo.vw_PersonelMaas', 'V') IS NOT NULL DROP VIEW dbo.vw_PersonelMaas;
GO
CREATE VIEW dbo.vw_PersonelMaas AS
    SELECT PersonelID, Ad, Soyad, Maas, DepartmanID FROM dbo.Personel;
GO

/* --- Rol yetkileri --- */

-- IK okuyucu: sadece maskelenmiş view'i okur. Personel tablosuna ERİŞEMEZ.
GRANT SELECT ON dbo.vw_PersonelIK TO rol_ik_okuyucu;
DENY  SELECT ON dbo.Personel      TO rol_ik_okuyucu;

-- Muhasebe: Maaş view'ini okur ve günceller.
GRANT SELECT, UPDATE ON dbo.vw_PersonelMaas TO rol_muhasebe;
DENY  SELECT ON dbo.Personel(TCKimlikNo)     TO rol_muhasebe;  -- TC'yi göremez
GRANT SELECT ON dbo.Departman                TO rol_muhasebe;

-- Yazılım şefi: Tüm Personel tablosunu okur (departmanı RLS filtreleyecek).
GRANT SELECT, INSERT, UPDATE ON dbo.Personel TO rol_yazilim_sef;
GRANT SELECT ON dbo.Departman                TO rol_yazilim_sef;

/* --- Kullanıcıları rollere ata --- */
ALTER ROLE rol_ik_okuyucu   ADD MEMBER ik_okuyucu;
ALTER ROLE rol_muhasebe     ADD MEMBER muh_yazar;
ALTER ROLE rol_yazilim_sef  ADD MEMBER yazilim_sef;
GO

/* --- Doğrulama --- */
SELECT dp.name AS Kullanici, r.name AS Rol
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
WHERE dp.type = 'S' AND r.name LIKE N'rol_%';
GO

PRINT '>>> Roller ve yetkiler yapılandırıldı.';
GO
