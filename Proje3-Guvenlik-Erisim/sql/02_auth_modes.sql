/* ============================================================================
   Proje 3 - Adım 02: Authentication (Kimlik Doğrulama) Yapılandırması
   ----------------------------------------------------------------------------
   Amaç  : SQL Server'ın iki auth modunu tanıtmak ve güvenli login örnekleri
           oluşturmak.
   Notlar:
     - Windows Authentication: Domain/Windows hesabıyla giriş, daha güvenli.
       Kimlik bilgileri ağda dolaşmaz, Active Directory tarafından yönetilir.
     - SQL Server Authentication: SQL'in kendi login/password mekanizması,
       harici (Windows olmayan) uygulamalar için kullanılır.
     - "Mixed Mode" her ikisini de destekler.
   ============================================================================ */

USE master;
GO

/* Mevcut authentication modunu öğren
   1 = Windows only, 0 = Mixed mode */
SELECT
    CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN 'Windows Authentication Only'
        WHEN 0 THEN 'Mixed Mode (SQL + Windows)'
    END AS AuthMode,
    SERVERPROPERTY('Edition')     AS Edition,
    SERVERPROPERTY('ProductVersion') AS Version;
GO

/* --------------------------------------------------------------------------
   Windows Authentication için login oluşturma (örnek - domain yoksa skip)
   -------------------------------------------------------------------------- */
-- CREATE LOGIN [BILGISAYAR\kullanici_adi] FROM WINDOWS;

/* --------------------------------------------------------------------------
   SQL Authentication: güçlü parola politikası zorunlu
   -------------------------------------------------------------------------- */
-- Varsa temizle
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'ik_okuyucu')
    DROP LOGIN ik_okuyucu;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'muh_yazar')
    DROP LOGIN muh_yazar;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'yazilim_sef')
    DROP LOGIN yazilim_sef;

CREATE LOGIN ik_okuyucu   WITH PASSWORD = N'G#cL5Ik_Ok2026!',
    CHECK_POLICY = ON,           -- Windows parola politikasını uygula
    CHECK_EXPIRATION = ON;       -- parola süresi dolabilir

CREATE LOGIN muh_yazar    WITH PASSWORD = N'M!h4s_Yz_2026$',
    CHECK_POLICY = ON,
    CHECK_EXPIRATION = ON;

CREATE LOGIN yazilim_sef  WITH PASSWORD = N'Yz!Sf_Sef_2026@',
    CHECK_POLICY = ON,
    CHECK_EXPIRATION = ON;
GO

/* Veritabanı kullanıcıları (DB user ↔ server login eşleşmesi) */
USE PersonelDB;
GO

IF USER_ID(N'ik_okuyucu')   IS NOT NULL DROP USER ik_okuyucu;
IF USER_ID(N'muh_yazar')    IS NOT NULL DROP USER muh_yazar;
IF USER_ID(N'yazilim_sef')  IS NOT NULL DROP USER yazilim_sef;

CREATE USER ik_okuyucu   FOR LOGIN ik_okuyucu;
CREATE USER muh_yazar    FOR LOGIN muh_yazar;
CREATE USER yazilim_sef  FOR LOGIN yazilim_sef;
GO

PRINT '>>> Loginler ve DB kullanıcıları hazır.';
SELECT name, type_desc, is_disabled, create_date FROM sys.server_principals
WHERE name IN (N'ik_okuyucu', N'muh_yazar', N'yazilim_sef');
GO
