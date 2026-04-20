# BLM4522 Ağ Tabanlı Paralel Dağıtım Sistemleri Proje Görevleri

## 1. Genel Kurallar ve Teslim Şartları
* Toplam 7 adet proje konusundan 5 tanesi seçilerek yapılmalıdır.
* Seçilen projelerden 2 tanesi vize sınavı yerine geçecektir ve vize tarihinde, belirlenen sınıfta imza karşılığı teslim edilecektir.
* Kalan 3 proje final notu olarak değerlendirilecek olup, teslim duyurusu sonradan yapılacaktır.
* Projeler tamamen bireysel olarak yapılmalıdır.
* Her proje için veritabanı yönetim platformu olarak MSSQL Management, PostgreSQL veya Oracle seçeneklerinden biri kullanılmalıdır.
* Farklı projeler için aynı platform kullanılabileceği gibi, her proje için farklı bir platform da tercih edilebilir.
* İnternet üzerinden hazır örnek veritabanları bulunarak kullanılabilir.
* Hazır veritabanlarının benzerliği normal karşılansa da, raporların ve uygulanan işlemlerin başka bir projeyle birebir aynı olması durumunda her iki proje de değerlendirme dışı bırakılır.
* Yapay zeka araçları kullanılabilir ancak öğrencinin yaptığı işlemleri öğrenmiş ve kavramış olması şarttır.

## 2. Geliştirme, Raporlama ve Video Süreçleri
* Aktif bir GIT hesabı kullanılmalı ve tüm çalışma aşamaları, dökümantasyonlar adım adım buraya yüklenmelidir.
* GIT kullanımında çalışmalar tek seferde değil, aşamalı olarak yüklenmelidir (örneğin; rapora başlandığı gün 2 sayfa, ertesi gün ilave 1 sayfa şeklinde).
* Projenin her detayını anlatan kapsamlı bir rapor hazırlanmalı ve GIT hesabına eklenmelidir.
* Vize notu için teslim edilecek ilk 2 projenin dosyaları, Nisan sonuna kadar eKampüs üzerinde açılan "Proje 1-2" başlığı altına yüklenmelidir.
* Her bir proje konusu için, tüm uygulama adımlarını ve detayları anlatan en az 10 dakikalık videolar çekilmelidir.
* Videolar, proje ve rapor işlemleri tamamen bittikten sonra çekilmeli ve teslim tarihinden önce yüklenmiş olmalıdır; sonradan yapılan yüklemeler kabul edilmeyecektir.
* Çekilen videolar doğrudan tıklandığında izlenebilen, erişim izni gerektirmeyen uygun bir platforma yüklenmelidir.

## 3. Proje Konuları

### Proje 1: Veritabanı Performans Optimizasyonu ve İzleme
* Büyük bir veritabanı üzerinde analiz yapılarak performans optimizasyonu teknikleri uygulanmalıdır.
* Sorgu optimizasyonu, disk alanı ve veri yoğunluğu yönetimi gerçekleştirilmelidir.
* Sorgu performansını izlemek ve hataları tespit etmek için SQL Profiler, Dynamic Management Views (DMV) gibi araçlar kullanılmalıdır.
* Sorgu hızını artırmak için doğru indeksleme yapılmalı ve gereksiz indeksler kaldırılmalıdır.
* Uzun süren sorgular analiz edilerek iyileştirilmelidir.
* Farklı roller için veritabanı erişim yönetimleri yapılandırılmalıdır.

### Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
* Veritabanı yedekleme ve felaketten kurtarma planları tasarlanmalıdır.
* SQL Server Backup, Point-in-time restore ve Database Mirroring gibi teknikler kullanılmalıdır.
* Tam (Full), Artık ve Fark yedekleme stratejileri oluşturulmalıdır.
* Yedekleme işlemleri zamanlayıcılar kullanılarak belirli aralıklarla otomatik hale getirilmelidir.
* Yanlışlıkla silinen verilerin geri getirilmesini kapsayan kurtarma süreçleri uygulanmalıdır.
* Alınan yedeklerin doğruluğunu test etmek için senaryolar oluşturulmalıdır.

### Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
* Veritabanı güvenliği, veri şifreleme ve güvenlik duvarı yönetimi konularına odaklanılmalıdır.
* Kullanıcı erişim yetkilerini yönetmek için SQL Server Authentication ve Windows Authentication kullanılmalıdır.
* TDE (Transparent Data Encryption) gibi araçlarla veritabanındaki hassas bilgiler şifrelenmelidir.
* Veritabanını korumak için SQL Injection saldırı testleri yapılmalıdır.
* Kullanıcı aktivitelerini takip etmek için SQL Server Audit özellikleri kullanılmalıdır.

### Proje 4: Veritabanı Yük Dengeleme ve Dağıtık Veritabanı Yapıları
* Birden fazla veritabanının yönetimi, yük dengeleme stratejileri ve replikasyon teknikleri uygulanmalıdır.
* SQL Server Replication ile verilerin çoğaltılması ve senkronizasyonu sağlanmalıdır.
* Yük dengelemesi için Always On Availability Groups veya Database Mirroring yapılandırılmalıdır.
* Başarısız bir sunucuya geçişi kapsayan (failover) stratejileri uygulanmalıdır.

### Proje 5: Veri Temizleme ve ETL Süreçleri Tasarımı
* Büyük veri kümelerinin işlenmesi, veri hatalarının tespiti ve entegrasyon için ETL (Extract, Transform, Load) süreçleri oluşturulmalıdır.
* SQL kullanılarak eksik, tutarsız veya yanlış formattaki veriler temizlenmelidir.
* Farklı kaynaklardan gelen veriler standartlaştırılarak dönüştürülmelidir.
* Temizlenen veriler doğru hedef veritabanlarına yüklenmelidir.
* Uygulanan veri temizleme ve dönüştürme süreçlerine dair veri kalitesi raporları oluşturulmalıdır.

### Proje 6: Veritabanı Yükseltme ve Sürüm Yönetimi
* Mevcut bir veritabanını daha yeni bir sürüme yükseltme stratejisi ve planı oluşturulmalıdır.
* DDL Triggers gibi araçlar kullanılarak şema değişiklikleri takip edilmeli ve sürüm yönetimi sağlanmalıdır.
* Yükseltme işlemi sonrasında oluşabilecek durumlar için test ve geri dönüş (rollback) planları hazırlanmalıdır.

### Proje 7: Veritabanı Yedekleme ve Otomasyon Çalışması
* Yedekleme süreçleri otomatikleştirilerek veritabanı yönetim süreçleri optimize edilmelidir.
* Otomasyon işlemi için SQL Server Agent kullanılmalıdır.
* PowerShell veya T-SQL Scripting kullanılarak yedeklerin düzenli alındığını gösteren raporlar oluşturulmalıdır.
* Yedekleme işlemleri başarısız olduğunda sistem yöneticilerine bildirim gönderecek uyarı mekanizmaları ayarlanmalıdır.