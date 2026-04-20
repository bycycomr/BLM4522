/* ============================================================================
   Proje 3 - Adım 07: Audit Loglarını Okuma
   ----------------------------------------------------------------------------
   Amaç : sys.fn_get_audit_file ile disk üzerindeki .sqlaudit dosyalarını
          sorgulanabilir hale getirmek.
   ============================================================================ */

USE master;
GO

/* Tüm audit olaylarını oku */
SELECT
    event_time,
    server_principal_name   AS GirisYapan,
    database_name           AS DB,
    schema_name             AS [Schema],
    object_name             AS [Object],
    action_id,
    succeeded,
    statement,
    additional_information
FROM sys.fn_get_audit_file('C:\SQLAudit\*', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO

/* Sadece başarısız login denemeleri */
PRINT N'--- Başarısız login denemeleri ---';
SELECT event_time, server_principal_name, client_ip, additional_information
FROM sys.fn_get_audit_file('C:\SQLAudit\*', DEFAULT, DEFAULT)
WHERE action_id = 'FLGF'   -- Failed Login
ORDER BY event_time DESC;
GO

/* Personel tablosuna yapılan değişiklikler */
PRINT N'--- Personel tablosunda INSERT/UPDATE/DELETE olayları ---';
SELECT event_time, server_principal_name, action_id, statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*', DEFAULT, DEFAULT)
WHERE object_name = N'Personel'
  AND action_id IN ('IN', 'UP', 'DL')
ORDER BY event_time DESC;
GO
