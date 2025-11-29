Mac Mouse Fix **3.0.6**, 'Geri' ve 'İleri' özelliğini daha fazla uygulamayla uyumlu hale getiriyor.
Ayrıca çeşitli hataları ve sorunları gideriyor.

### Geliştirilmiş 'Geri' ve 'İleri' Özelliği

'Geri' ve 'İleri' fare düğmesi atamaları artık **daha fazla uygulamada çalışıyor**:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed ve diğer kod editörleri
- Ön İzleme, Notlar, Sistem Ayarları, App Store ve Müzik gibi birçok yerleşik Apple uygulaması
- Adobe Acrobat
- Zotero
- Ve daha fazlası!

Uygulama, [LinearMouse](https://github.com/linearmouse/linearmouse)'daki harika 'Evrensel Geri ve İleri' özelliğinden ilham alıyor. LinearMouse'un desteklediği tüm uygulamaları desteklemeli. \
Ayrıca Sistem Ayarları, App Store, Apple Notlar ve Adobe Acrobat gibi normalde geri ve ileri gitmek için klavye kısayolları gerektiren bazı uygulamaları da destekliyor. Mac Mouse Fix artık bu uygulamaları algılayacak ve uygun klavye kısayollarını simüle edecek.

[GitHub Issue'da talep edilen](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) her uygulama artık desteklenmeli! (Geri bildirimleriniz için teşekkürler!) \
Henüz çalışmayan bir uygulama bulursan, [özellik talebi](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request) ile bana bildir.



### 'Kaydırma Aralıklı Olarak Durma' Hatasının Giderilmesi

Bazı kullanıcılar, **yumuşak kaydırmanın** rastgele durabileceği bir [sorun](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) yaşadı.

Sorunu hiçbir zaman yeniden oluşturamadım, ancak olası bir düzeltme uyguladım:

Uygulama artık ekran senkronizasyonunu kurarken başarısız olursa birden fazla kez yeniden deneyecek. \
Yeniden denemeden sonra hala çalışmazsa, uygulama:

- Sorunu çözebilecek 'Mac Mouse Fix Helper' arka plan işlemini yeniden başlatacak
- Hatanın teşhisine yardımcı olabilecek bir çökme raporu oluşturacak

Umarım sorun artık çözülmüştür! Değilse, [hata raporu](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) veya [e-posta](http://redirect.macmousefix.com/?target=mailto-noah) ile bana bildir.



### Geliştirilmiş Serbest Dönen Kaydırma Tekerleği Davranışı

Mac Mouse Fix artık MX Master faresi (veya serbest dönen kaydırma tekerleğine sahip başka bir fare) üzerinde kaydırma tekerleğini serbest döndürdüğünde **kaydırmayı hızlandırmayacak**.

Bu 'kaydırma hızlandırma' özelliği normal kaydırma tekerleklerinde kullanışlı olsa da, serbest dönen bir kaydırma tekerleğinde kontrol etmeyi zorlaştırabilir.

**Not:** Mac Mouse Fix şu anda MX Master dahil çoğu Logitech faresiyle tam uyumlu değil. Tam destek eklemeyi planlıyorum, ancak muhtemelen biraz zaman alacak. Bu arada, bildiğim Logitech desteğine sahip en iyi üçüncü taraf sürücü [SteerMouse](https://plentycom.jp/en/steermouse/).





### Hata Düzeltmeleri

- Mac Mouse Fix'in bazen Sistem Ayarları'nda daha önce devre dışı bırakılan klavye kısayollarını yeniden etkinleştirdiği bir sorun düzeltildi  
- 'Lisansı Etkinleştir'e tıklandığında oluşan çökme düzeltildi 
- 'Lisansı Etkinleştir'e tıkladıktan hemen sonra 'İptal'e tıklandığında oluşan çökme düzeltildi (Rapor için teşekkürler, Ali!)
- Mac'ine hiçbir ekran bağlı değilken Mac Mouse Fix'i kullanmaya çalışırken oluşan çökmeler düzeltildi 
- Uygulamada sekmeler arasında geçiş yaparken oluşan bellek sızıntısı ve diğer bazı arka plan sorunları düzeltildi 

### Görsel İyileştirmeler

- [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)'te ortaya çıkan, Hakkında sekmesinin bazen çok uzun olduğu bir sorun düzeltildi
- 'Ücretsiz günler bitti' bildirimindeki metin artık Çince'de kesilmiyor
- Bir girdi kaydettikten sonra '+' alanının gölgesindeki görsel hata düzeltildi
- 'Lisans Anahtarınızı Girin' ekranında yer tutucu metnin merkezden kaymış görünebileceği nadir bir hata düzeltildi
- Koyu/açık mod arasında geçiş yaptıktan sonra uygulamada görüntülenen bazı sembollerin yanlış renge sahip olduğu bir sorun düzeltildi

### Diğer İyileştirmeler

- Sekme geçiş animasyonu gibi bazı animasyonlar biraz daha verimli hale getirildi  
- 'Lisans Anahtarınızı Girin' ekranında Touch Bar metin tamamlama devre dışı bırakıldı 
- Çeşitli küçük arka plan iyileştirmeleri

*Claude'un mükemmel yardımıyla düzenlendi.*

---

Ayrıca önceki sürüm [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)'e göz at.