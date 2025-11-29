Mac Mouse Fix **3.0.4** gizlilik, verimlilik ve güvenilirliği iyileştiriyor.\
Yeni bir çevrimdışı lisanslama sistemi sunuyor ve birkaç önemli hatayı düzeltiyor.

### Gelişmiş Gizlilik ve Verimlilik

3.0.4, internet bağlantılarını mümkün olduğunca azaltan yeni bir çevrimdışı lisans doğrulama sistemi sunuyor.\
Bu, gizliliği iyileştiriyor ve bilgisayarının sistem kaynaklarını koruyor.\
Lisanslı olduğunda, uygulama artık %100 çevrimdışı çalışıyor!

<details>
<summary><b>Daha fazla detay için buraya tıkla</b></summary>
Önceki sürümler her başlatmada lisansları çevrimiçi doğruluyordu ve bu, üçüncü taraf sunucular (GitHub ve Gumroad) tarafından bağlantı kayıtlarının saklanmasına potansiyel olarak izin veriyordu. Yeni sistem gereksiz bağlantıları ortadan kaldırıyor – ilk lisans aktivasyonundan sonra, yalnızca yerel lisans verileri bozulmuşsa internete bağlanıyor.
<br><br>
Hiçbir kullanıcı davranışı benim tarafımdan hiçbir zaman kaydedilmese de, önceki sistem teorik olarak üçüncü taraf sunucuların IP adreslerini ve bağlantı zamanlarını kaydetmesine izin veriyordu. Gumroad ayrıca lisans anahtarını kaydedebilir ve bunu Mac Mouse Fix'i satın aldığında senin hakkında kaydettikleri kişisel bilgilerle potansiyel olarak ilişkilendirebilirdi.
<br><br>
Orijinal lisanslama sistemini oluştururken bu ince gizlilik sorunlarını düşünmemiştim, ama şimdi Mac Mouse Fix mümkün olduğunca gizli ve internetsiz!
<br><br>
Ayrıca <a href=https://gumroad.com/privacy>Gumroad'un gizlilik politikasına</a> ve benim <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub yorumuma</a> göz at.

</details>

### Hata Düzeltmeleri

- 'Spaces & Mission Control' için 'Tıkla ve Sürükle' kullanırken macOS'un bazen takılıp kaldığı bir hata düzeltildi.
- Mac Mouse Fix 'Tıklama' eylemleri ('Mission Control' gibi) kullanırken Sistem Ayarları'ndaki klavye kısayollarının bazen silindiği bir hata düzeltildi.
- Uygulamayı zaten satın almış kullanıcılara 'Ücretsiz günler bitti' bildirimi göstererek uygulamanın bazen çalışmayı durdurduğu [bir hata](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) düzeltildi.
    - Bu hatayı yaşadıysan, yaşattığım rahatsızlık için içtenlikle özür dilerim. [Buradan iade başvurusunda](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund) bulunabilirsin.
- Uygulamanın ana penceresini alma yöntemi iyileştirildi, bu da 'Lisansı Etkinleştir' ekranının bazen görünmediği bir hatayı düzeltmiş olabilir.

### Kullanılabilirlik İyileştirmeleri

- 'Lisansı Etkinleştir' ekranındaki metin alanına boşluk ve satır sonu girişi imkansız hale getirildi.
    - Bu yaygın bir kafa karışıklığı noktasıydı, çünkü Gumroad'un e-postalarından lisans anahtarını kopyalarken yanlışlıkla gizli bir satır sonu seçmek çok kolay.
- Bu güncelleme notları İngilizce olmayan kullanıcılar için otomatik olarak çevriliyor (Claude tarafından destekleniyor). Umarım faydalı olur! Herhangi bir sorunla karşılaşırsan, bana bildir. Bu, geçen yıl boyunca geliştirdiğim yeni bir çeviri sisteminin ilk gösterimi.

### macOS 10.14 Mojave için (Resmi Olmayan) Destek Kaldırıldı

Mac Mouse Fix 3, resmi olarak macOS 11 Big Sur ve sonrasını destekliyor. Ancak, bazı aksaklıkları ve grafik sorunlarını kabul etmeye istekli kullanıcılar için Mac Mouse Fix 3.0.3 ve önceki sürümler hala macOS 10.14.4 Mojave'de kullanılabiliyordu.

Mac Mouse Fix 3.0.4 bu desteği kaldırıyor ve **artık macOS 10.15 Catalina gerektiriyor**. \
Bunun neden olduğu herhangi bir rahatsızlık için özür dilerim. Bu değişiklik, modern Swift özelliklerini kullanarak geliştirilmiş lisanslama sistemini uygulamama olanak sağladı. Mojave kullanıcıları Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)'ü veya [Mac Mouse Fix 2'nin en son sürümünü](https://redirect.macmousefix.com/?target=mmf2-latest) kullanmaya devam edebilir. Umarım bu herkes için iyi bir çözümdür.

### Arka Planda İyileştirmeler

- Mac Mouse Fix'in yapılandırma dosyasını insan tarafından okunabilir ve düzenlenebilir tutarken daha güçlü veri modellemeye olanak tanıyan yeni bir 'MFDataClass' sistemi uygulandı.
- Gumroad dışındaki ödeme platformlarını ekleme desteği oluşturuldu. Böylece gelecekte yerelleştirilmiş ödemeler olabilir ve uygulama farklı ülkelere satılabilir.
- Yeniden üretilmesi zor hatalar yaşayan kullanıcılar için daha etkili "Hata Ayıklama Sürümleri" oluşturmama olanak tanıyan geliştirilmiş günlük kaydı.
- Diğer birçok küçük iyileştirme ve temizlik çalışması.

*Claude'un mükemmel yardımıyla düzenlendi.*

---

Ayrıca önceki sürüm [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)'e göz at.