/* ============================================================================
   Proje 3 - Adım 06: SQL Server Audit - Kullanıcı Aktivitesi Takibi
   ----------------------------------------------------------------------------
   Amaç : Kim, ne zaman, hangi veriye erişti veya değiştirdi? Bunu bağımsız
          bir log'a yazmak.
   Mimari:
     Server Audit  (nereye yazılacak)
        └─> Server Audit Specification  (server seviyesi olaylar: LOGIN vb.)
        └─> Database Audit Specification (DB seviyesi: SELECT/UPDATE/DELETE)
   ============================================================================ */

USE master;
GO

/* --- Temizlik --- */
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'Srv_Audit_Spec_Logins')
    ALTER SERVER AUDIT SPECIFICATION Srv_Audit_Spec_Logins WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = N'Srv_Audit_Spec_Logins')
    DROP SERVER AUDIT SPECIFICATION Srv_Audit_Spec_Logins;

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'PersonelDB_Audit')
    ALTER SERVER AUDIT PersonelDB_Audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'PersonelDB_Audit')
    DROP SERVER AUDIT PersonelDB_Audit;
GO

/* --- 1) Audit hedefi (dosyaya yazacak) --- */
EXEC xp_create_subdir N'C:\SQLAudit';

CREATE SERVER AUDIT PersonelDB_Audit
TO FILE (
    FILEPATH = N'C:\SQLAudit\',
    MAXSIZE = 50 MB,
    MAX_ROLLOVER_FILES = 20,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE    -- audit yazamazsa sistem çalışmaya devam etsin
);
GO

ALTER SERVER AUDIT PersonelDB_Audit WITH (STATE = ON);
GO

/* --- 2) Sunucu seviyesi: başarılı/başarısız girişleri kaydet --- */
CREATE SERVER AUDIT SPECIFICATION Srv_Audit_Spec_Logins
FOR SERVER AUDIT PersonelDB_Audit
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (FAILED_LOGIN_GROUP),
    ADD (LOGOUT_GROUP)
WITH (STATE = ON);
GO

/* --- 3) DB seviyesi: hassas tabloya her erişimi kaydet --- */
USE PersonelDB;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N'DB_Audit_Spec_Personel')
    ALTER DATABASE AUDIT SPECIFICATION DB_Audit_Spec_Personel WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N'DB_Audit_Spec_Personel')
    DROP DATABASE AUDIT SPECIFICATION DB_Audit_Spec_Personel;
GO

CREATE DATABASE AUDIT SPECIFICATION DB_Audit_Spec_Personel
FOR SERVER AUDIT PersonelDB_Audit
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Personel BY public),
    ADD (SCHEMA_OBJECT_ACCESS_GROUP),
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

PRINT '>>> Audit yapılandırması etkin. Log dosyaları: C:\SQLAudit\';
SELECT name, is_state_enabled, create_date FROM sys.server_audits;
GO
