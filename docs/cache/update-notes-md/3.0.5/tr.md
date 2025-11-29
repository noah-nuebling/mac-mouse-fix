Mac Mouse Fix **3.0.5**, birkaç hatayı düzeltiyor, performansı iyileştiriyor ve uygulamaya biraz daha parlaklık katıyor. \
Ayrıca macOS 26 Tahoe ile uyumlu.

### Trackpad Kaydırma Simülasyonunda İyileştirmeler

- Kaydırma sistemi artık uygulamaların kaydırmayı durdurması için trackpad üzerinde iki parmakla dokunmayı simüle edebiliyor.
    - Bu, iPhone veya iPad uygulamalarını çalıştırırken kullanıcı durmayı seçtikten sonra kaydırmanın sıklıkla devam etmesi sorununu düzeltiyor.
- Parmakları trackpad'den kaldırma simülasyonundaki tutarsızlık düzeltildi.
    - Bu, bazı durumlarda optimal olmayan davranışlara neden olabiliyordu.



### macOS 26 Tahoe Uyumluluğu

macOS 26 Tahoe Beta çalıştırılırken, uygulama artık kullanılabilir durumda ve arayüzün çoğu doğru şekilde çalışıyor.



### Performans İyileştirmesi

"Kaydır ve Gezin" hareketinde Tıkla ve Sürükle performansı iyileştirildi. \
Testlerimde, CPU kullanımı ~%50 oranında azaldı!

**Arka Plan**

"Kaydır ve Gezin" hareketi sırasında, Mac Mouse Fix gerçek fare imlecini sabit tutarken şeffaf bir pencerede sahte bir fare imleci çiziyor. Bu, farenizi ne kadar hareket ettirirseniz ettirin, kaydırmaya başladığınız arayüz öğesini kaydırmaya devam edebilmenizi sağlıyor.

Performans iyileştirmesi, bu şeffaf pencerede zaten kullanılmayan varsayılan macOS olay işleme sistemini kapatarak elde edildi.





### Hata Düzeltmeleri

- Artık Wacom çizim tabletlerinden gelen kaydırma olayları göz ardı ediliyor.
    - Daha önce Mac Mouse Fix, @frenchie1980 tarafından GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233)'te bildirilen şekilde Wacom tabletlerde düzensiz kaydırmaya neden oluyordu. (Teşekkürler!)
    
- Mac Mouse Fix 3.0.4'teki yeni lisanslama sisteminin bir parçası olarak eklenen Swift Concurrency kodunun doğru thread üzerinde çalışmaması hatasını düzelttik.
    - Bu, macOS Tahoe'da çökmelere neden oluyordu ve muhtemelen lisanslama etrafındaki diğer ara sıra oluşan hatalara da yol açıyordu.
- Çevrimdışı lisansların kodunu çözen kodun sağlamlığı iyileştirildi.
    - Bu, Apple'ın API'lerindeki, Intel Mac Mini'mde çevrimdışı lisans doğrulamasının her zaman başarısız olmasına neden olan bir sorunu aşıyor. Bunun tüm Intel Mac'lerde gerçekleştiğini ve @toni20k5267 tarafından GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356)'da bildirilen şekilde, bazı kişiler için (3.0.4'te zaten ele alınan) "Ücretsiz günler bitti" hatasının hala oluşmasının nedeni olduğunu varsayıyorum. (Teşekkür ederim!)
        - "Ücretsiz günler bitti" hatasını yaşadıysanız, bunun için özür dilerim! [Buradan](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) para iadesi alabilirsiniz.
     
     

### Kullanıcı Deneyimi İyileştirmeleri

- Kullanıcıların Mac Mouse Fix'i etkinleştirmesini engelleyen macOS hataları için adım adım çözümler sunan diyaloglar devre dışı bırakıldı.
    - Bu sorunlar yalnızca macOS 13 Ventura ve 14 Sonoma'da oluşuyordu. Artık bu diyaloglar yalnızca ilgili oldukları macOS sürümlerinde görünüyor.
    - Diyalogların tetiklenmesi de biraz daha zorlaştırıldı – daha önce bazen çok yardımcı olmadıkları durumlarda görünüyorlardı.
    
- "Ücretsiz günler bitti" bildiriminin üzerine doğrudan bir "Lisansı Etkinleştir" bağlantısı eklendi.
    - Bu, Mac Mouse Fix lisansını etkinleştirmeyi daha da kolay hale getiriyor!

### Görsel İyileştirmeler

- "Yazılım Güncellemesi" penceresinin görünümü biraz iyileştirildi. Artık macOS 26 Tahoe ile daha iyi uyum sağlıyor.
    - Bu, Mac Mouse Fix'in güncellemeleri yönetmek için kullandığı "Sparkle 1.27.3" framework'ünün varsayılan görünümü özelleştirilerek yapıldı.
- Hakkında sekmesinin altındaki metnin Çince'de bazen kesilmesi sorunu, pencere biraz genişletilerek düzeltildi.
- Hakkında sekmesinin altındaki metnin hafif merkez dışı olması düzeltildi.
- Düğmeler sekmesindeki "Klavye Kısayolu..." seçeneğinin altındaki boşluğun çok küçük olmasına neden olan hata düzeltildi.

### Altyapı Değişiklikleri

- "SnapKit" framework'üne olan bağımlılık kaldırıldı.
    - Bu, uygulamanın boyutunu 19,8 MB'den 19,5 MB'ye hafifçe düşürüyor.
- Kod tabanında çeşitli diğer küçük iyileştirmeler.

*Claude'un mükemmel yardımıyla düzenlendi.*

---

Ayrıca bir önceki sürüm [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4)'e de göz atın.