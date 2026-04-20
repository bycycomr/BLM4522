/* ============================================================================
   Proje 3 - Adım 05: SQL Injection Saldırı Testleri ve Savunma
   ----------------------------------------------------------------------------
   Amaç : Dinamik SQL'in tehlikesini GÖSTERMEK ve parameterized query ile
          doğru savunmayı sunmak.
   Not  : Bu örnek eğitim amaçlıdır. ASLA üretimde string concat ile SQL
          inşa etmeyin.
   ============================================================================ */

USE PersonelDB;
GO

/* --------------------------------------------------------------------------
   SAVUNMASIZ PROSEDÜR — string concatenation kullanır
   Gerçek bir web uygulaması login ekranını simüle ediyoruz:
     SELECT * FROM Personel WHERE Email = '<input>';
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.usp_AramaSavunmasiz','P') IS NOT NULL
    DROP PROCEDURE dbo.usp_AramaSavunmasiz;
GO
CREATE PROCEDURE dbo.usp_AramaSavunmasiz
    @email NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) =
        N'SELECT PersonelID, Ad, Soyad, Email, Maas FROM dbo.Personel WHERE Email = ''' + @email + N'''';
    PRINT N'Çalıştırılan SQL: ' + @sql;
    EXEC (@sql);
END
GO

/* --------------------------------------------------------------------------
   GÜVENLİ PROSEDÜR — parameterized query
   sp_executesql parametreleri bind eder; '-- veya ' OR 1=1 etkisiz kalır.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.usp_AramaGuvenli','P') IS NOT NULL
    DROP PROCEDURE dbo.usp_AramaGuvenli;
GO
CREATE PROCEDURE dbo.usp_AramaGuvenli
    @email NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PersonelID, Ad, Soyad, Email, Maas
    FROM dbo.Personel
    WHERE Email = @email;
END
GO

/* --------------------------------------------------------------------------
   SALDIRI TESTLERİ
   -------------------------------------------------------------------------- */
PRINT N'========== 1. Normal giriş ==========';
EXEC dbo.usp_AramaSavunmasiz @email = N'ahmet@sirket.com';

PRINT N'========== 2. SQL Injection: OR 1=1 ==========';
PRINT N'Saldırgan girişi: x'' OR 1=1 --';
EXEC dbo.usp_AramaSavunmasiz @email = N'x'' OR 1=1 --';
-- BEKLENEN: Tüm personel listelenir! Maaş bilgileri dahil HER ŞEY sızar.

PRINT N'========== 3. SQL Injection: UNION ile şema sızıntısı ==========';
PRINT N'Saldırgan girişi: x'' UNION SELECT 1, name COLLATE DATABASE_DEFAULT, type_desc COLLATE DATABASE_DEFAULT, ''--'', 0 FROM sys.objects --';
BEGIN TRY
    -- COLLATE DATABASE_DEFAULT: gercek saldirgan da farkli collation hatasini
    -- bu sekilde bypass eder; demo'da da gostermeli.
    EXEC dbo.usp_AramaSavunmasiz @email = N'x'' UNION SELECT 1, name COLLATE DATABASE_DEFAULT, type_desc COLLATE DATABASE_DEFAULT, ''--'', 0 FROM sys.objects WHERE type IN (''U'',''V'') --';
END TRY
BEGIN CATCH
    PRINT N'UNION injection hata verdi (error message bile sema sizdirir!): ' + ERROR_MESSAGE();
END CATCH
-- BEKLENEN: Veritabanındaki tüm tablo ve view isimleri listelenir.

PRINT N'========== 4. GÜVENLİ prosedür aynı saldırıya karşı ==========';
EXEC dbo.usp_AramaGuvenli @email = N'x'' OR 1=1 --';
-- BEKLENEN: Hiçbir satır dönmez. Saldırı dizisi literal string olarak
--          bind edildiği için Email sütununda eşleşme yoktur.

PRINT N'========== 5. Güvenli prosedür - normal giriş ==========';
EXEC dbo.usp_AramaGuvenli @email = N'ahmet@sirket.com';
GO
