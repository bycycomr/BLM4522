/* ============================================================================
   Proje 3 - Adım 08: Row-Level Security (RLS) — Satır Düzeyinde Güvenlik
   ----------------------------------------------------------------------------
   Amaç : Her yazılım şefi SADECE kendi departmanındaki personeli görsün.
          Aynı sorgu, çalıştıran kullanıcıya göre farklı sonuç dönsün.
   Yöntem:
     1) SCHEMABINDING'li inline TVF: filtre fonksiyonu.
     2) SECURITY POLICY: fonksiyonu tabloya FILTER PREDICATE olarak uygular.
   ============================================================================ */

USE PersonelDB;
GO

/* --- Departman eşlemesi: kullanıcı adına göre hangi departmana erişeceği --- */
IF OBJECT_ID(N'dbo.KullaniciDepartman','U') IS NOT NULL
    DROP TABLE dbo.KullaniciDepartman;

CREATE TABLE dbo.KullaniciDepartman
(
    KullaniciAdi SYSNAME NOT NULL PRIMARY KEY,
    DepartmanID  INT NOT NULL
);

INSERT INTO dbo.KullaniciDepartman VALUES
 (N'yazilim_sef', 2);  -- Yazılım Geliştirme departmanı
GO

/* --- Filtre fonksiyonu --- */
IF OBJECT_ID(N'Security.fn_DepartmanFiltre','IF') IS NOT NULL
    DROP FUNCTION Security.fn_DepartmanFiltre;
IF SCHEMA_ID(N'Security') IS NULL EXEC(N'CREATE SCHEMA Security');
GO

CREATE FUNCTION Security.fn_DepartmanFiltre(@DepartmanID AS INT)
    RETURNS TABLE
    WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Erisim
    WHERE
        -- sysadmin veya tablo sahibi herşeyi görür
        IS_MEMBER(N'db_owner') = 1
        -- Kendi kullanıcı adı ve departmanı eşleşenler görür
        OR EXISTS (
            SELECT 1 FROM dbo.KullaniciDepartman
            WHERE KullaniciAdi = SUSER_SNAME()
              AND DepartmanID  = @DepartmanID
        );
GO

/* --- Security policy: Personel tablosuna uygula --- */
IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'PersonelRLS')
    DROP SECURITY POLICY PersonelRLS;
GO

CREATE SECURITY POLICY PersonelRLS
ADD FILTER PREDICATE Security.fn_DepartmanFiltre(DepartmanID)
    ON dbo.Personel,
ADD BLOCK  PREDICATE Security.fn_DepartmanFiltre(DepartmanID)
    ON dbo.Personel AFTER INSERT
WITH (STATE = ON);
GO

PRINT '>>> Row-Level Security etkin.';
PRINT '   - yazilim_sef olarak bağlanıp SELECT * FROM dbo.Personel çalıştırın:';
PRINT '     yalnızca DepartmanID=2 satırlarını göreceksiniz.';
PRINT '   - sa/db_owner olarak çalıştırırsanız tüm satırları görürsünüz.';
GO
