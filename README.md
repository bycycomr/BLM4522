# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri Projeleri

Bu repo, **BLM4522** dersi kapsamında vize notu için teslim edilen iki projenin tüm kaynak kodlarını, SQL script'lerini ve raporlarını içerir.

## Seçilen Projeler

| # | Proje | Konu | Klasör |
|---|-------|------|--------|
| 2 | Veritabanı Yedekleme ve Felaketten Kurtarma Planı | Full/Differential/Log backup, Point-in-time restore, otomatik yedekleme | [Youtube-Proje2-Yedekleme-Kurtarma/](https://youtu.be/_5jdmQ33LTU) 
| 3 | Veritabanı Güvenliği ve Erişim Kontrolü | Authentication, roller, TDE, SQL Injection testleri, Audit | [Youtube-Proje3-Guvenlik-Erisim/](https://youtu.be/PAsPF416qdA)

## Ortam

- **DBMS:** Microsoft SQL Server (Developer/Standard)
- **Yönetim Aracı:** SQL Server Management Studio (SSMS) / `sqlcmd`
- **İşletim Sistemi:** Windows 11
- **Örnek Veritabanı:** AdventureWorks (Microsoft'un resmi örnek DB'si)

## Yapı

Her proje klasöründe:
- `sql/` — çalıştırılacak T-SQL script'leri (sıra numaralı)
- `docs/` — rapor ve ekran görüntüleri
- Proje özel alt klasörleri (ör. `backups/`, `tests/`)

## Not

Projeler **bireysel** olarak hazırlanmıştır. `.bak` uzantılı yedek dosyaları boyut nedeniyle repo'ya dahil edilmez (bkz. `.gitignore`); bunun yerine yedekleme komutları ve çıktıları raporda belgelenir.
