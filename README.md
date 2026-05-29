# BLM4522 - Ağ Tabanlı Paralel Dağıtım Sistemleri Projeleri

Bu repo, **BLM4522** dersi kapsamında seçilen projelerin tüm kaynak kodlarını, SQL script'lerini ve raporlarını içerir. (7 konudan 5'i seçilmektedir.)

## Seçilen Projeler

7 konudan 5'i seçilmiştir: **2 proje vize**, **3 proje final** notu için.

### 📘 Vize Projeleri (2 adet)

| # | Proje | Konu | Klasör |
|---|-------|------|--------|
| 2 | Veritabanı Yedekleme ve Felaketten Kurtarma Planı | Full/Differential/Log backup, Point-in-time restore, otomatik yedekleme | [Youtube-Proje2-Yedekleme-Kurtarma/](https://youtu.be/_5jdmQ33LTU) 
| 3 | Veritabanı Güvenliği ve Erişim Kontrolü | Authentication, roller, TDE, SQL Injection testleri, Audit | [Youtube-Proje3-Guvenlik-Erisim/](https://youtu.be/PAsPF416qdA)

### 📕 Final Projeleri (3 adet)

| # | Proje | Konu | Klasör |
|---|-------|------|--------|
| 1 | Veritabanı Performans Optimizasyonu ve İzleme | DMV/STATISTICS izleme, indeksleme, disk/yoğunluk yönetimi, RBAC | [Proje1-Performans-Optimizasyonu/](./Proje1-Performans-Optimizasyonu) |
| 5 | Veri Temizleme ve ETL Süreçleri Tasarımı | Kirli ham veri, cleansing/transform, MERGE ile load, kalite raporu | [Proje5-ETL-Veri-Temizleme/](./Proje5-ETL-Veri-Temizleme) |
| 7 | Veritabanı Yedekleme ve Otomasyon | Yedek prosedürleri, SQL Server Agent job'ları, Database Mail bildirim, yedek raporu | [Proje7-Yedekleme-Otomasyonu/](./Proje7-Yedekleme-Otomasyonu) |

## Ortam

- **DBMS:** Microsoft SQL Server (Developer/Standard)
- **Yönetim Aracı:** SQL Server Management Studio (SSMS) / `sqlcmd`
- **İşletim Sistemi:** Windows 11
- **Örnek Veritabanları:** Her proje kendi DB'sini kurar (`SatisDB`, `PersonelDB`, `TemizlemeDB`, `OtomasyonDB`, `OkulDB`)

## Yapı

Her proje klasöründe:
- `sql/` — çalıştırılacak T-SQL script'leri (sıra numaralı)
- `docs/` — rapor ve ekran görüntüleri
- Proje özel alt klasörleri (ör. `backups/`, `tests/`)

## Not

Projeler **bireysel** olarak hazırlanmıştır. `.bak` uzantılı yedek dosyaları boyut nedeniyle repo'ya dahil edilmez (bkz. `.gitignore`); bunun yerine yedekleme komutları ve çıktıları raporda belgelenir.
