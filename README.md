# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri Projeleri

Bu repo, **BLM4522** dersi kapsamında seçilen projelerin tüm kaynak kodlarını, SQL script'lerini ve raporlarını içerir. (7 konudan 5'i seçilmektedir.)

## Seçilen Projeler

| # | Proje | Konu | Klasör |
|---|-------|------|--------|
| 1 | Veritabanı Performans Optimizasyonu ve İzleme | DMV/STATISTICS izleme, indeksleme, disk/yoğunluk yönetimi, RBAC | [Proje1-Performans-Optimizasyonu/](./Proje1-Performans-Optimizasyonu) |
| 2 | Veritabanı Yedekleme ve Felaketten Kurtarma Planı | Full/Differential/Log backup, Point-in-time restore, otomatik yedekleme | [Proje2-Yedekleme-Kurtarma/](./Proje2-Yedekleme-Kurtarma) |
| 3 | Veritabanı Güvenliği ve Erişim Kontrolü | Authentication, roller, TDE, SQL Injection testleri, Audit | [Proje3-Guvenlik-Erisim/](./Proje3-Guvenlik-Erisim) |
| 5 | Veri Temizleme ve ETL Süreçleri Tasarımı | Kirli ham veri, cleansing/transform, MERGE ile load, kalite raporu | [Proje5-ETL-Veri-Temizleme/](./Proje5-ETL-Veri-Temizleme) |

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
