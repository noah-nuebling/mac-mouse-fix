Mac Mouse Fix **3.0.3**, macOS 15 Sequoia için hazır. Ayrıca bazı kararlılık sorunlarını düzeltiyor ve birkaç küçük iyileştirme sunuyor.

### macOS 15 Sequoia desteği

Uygulama artık macOS 15 Sequoia altında düzgün çalışıyor!

- Çoğu arayüz animasyonu macOS 15 Sequoia altında bozuktu. Artık her şey yeniden düzgün çalışıyor!
- Kaynak kodu artık macOS 15 Sequoia altında derlenebiliyor. Daha önce, Swift derleyicisiyle ilgili uygulamanın derlenmesini engelleyen sorunlar vardı.

### Kaydırma çökmelerinin giderilmesi

Mac Mouse Fix 3.0.2'den bu yana, kaydırma sırasında Mac Mouse Fix'in periyodik olarak kendini devre dışı bırakıp yeniden etkinleştirmesiyle ilgili [birçok rapor](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) geldi. Bu durum, 'Mac Mouse Fix Helper' arka plan uygulamasının çökmesinden kaynaklanıyordu. Bu güncelleme, aşağıdaki değişikliklerle bu çökmeleri düzeltmeye çalışıyor:

- Kaydırma mekanizması, bu çökmelere yol açmış gibi görünen uç durumla karşılaştığında çökmek yerine kurtulmaya ve çalışmaya devam etmeye çalışacak.
- Uygulamada beklenmeyen durumların ele alınma şeklini daha genel olarak değiştirdim: Her zaman hemen çökmek yerine, uygulama artık birçok durumda beklenmeyen durumlardan kurtulmaya çalışacak.
    
    - Bu değişiklik, yukarıda açıklanan kaydırma çökmelerinin düzeltmelerine katkıda bulunuyor. Diğer çökmeleri de önleyebilir.
  
Not: Bu çökmeleri kendi bilgisayarımda hiçbir zaman yeniden üretemedim ve neyin bunlara neden olduğundan hala emin değilim, ancak aldığım raporlara dayanarak bu güncelleme herhangi bir çökmeyi önlemeli. Hala kaydırma sırasında çökmeler yaşıyorsan veya 3.0.2 altında çökmeler *yaşadıysan*, deneyimini ve tanı verilerini GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988)'de paylaşman değerli olur. Bu, sorunu anlamamı ve Mac Mouse Fix'i geliştirmemi sağlar. Teşekkürler!

### Kaydırma takılmalarının giderilmesi

3.0.2'de, muhtemelen Apple'ın VSync API'leriyle ilgili sorunlardan kaynaklanan kaydırma takılmalarını azaltmak amacıyla Mac Mouse Fix'in sisteme kaydırma olaylarını gönderme şeklinde değişiklikler yaptım.

Ancak daha kapsamlı testler ve geri bildirimlerden sonra, 3.0.2'deki yeni mekanizmanın bazı senaryolarda kaydırmayı daha akıcı, diğerlerinde ise daha takılmalı hale getirdiği görülüyor. Özellikle Firefox'ta belirgin şekilde daha kötü görünüyordu. \
Genel olarak, yeni mekanizmanın kaydırma takılmalarını genel anlamda iyileştirdiği net değildi. Ayrıca, yukarıda açıklanan kaydırma çökmelerine katkıda bulunmuş olabilir.

Bu nedenle yeni mekanizmayı devre dışı bıraktım ve kaydırma olayları için VSync mekanizmasını Mac Mouse Fix 3.0.0 ve 3.0.1'deki haline geri döndürdüm.

Daha fazla bilgi için GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875)'e bak.

### Para iadesi

3.0.1 ve 3.0.2'deki kaydırma değişiklikleriyle ilgili sorunlar için özür dilerim. Bunun getireceği sorunları büyük ölçüde hafife aldım ve bu sorunları ele almakta yavaş kaldım. Bu deneyimden ders çıkarmak ve gelecekte bu tür değişikliklerle daha dikkatli olmak için elimden geleni yapacağım. Ayrıca etkilenen herkese para iadesi sunmak istiyorum. İlgileniyorsan [buraya](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) tıklaman yeterli.

### Daha akıllı güncelleme mekanizması

Bu değişiklikler Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) ve [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5)'ten getirildi. Detaylar hakkında daha fazla bilgi edinmek için sürüm notlarına göz at. İşte bir özet:

- Kullanıcıya hangi güncellemenin gösterileceğine karar veren yeni, daha akıllı bir mekanizma var.
- Sparkle 1.26.0 güncelleme çerçevesinden en son Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)'e geçildi.
- Uygulamanın Mac Mouse Fix'in yeni bir sürümünün mevcut olduğunu bildirmek için gösterdiği pencere artık JavaScript'i destekliyor, bu da güncelleme notlarının daha güzel biçimlendirilmesine olanak tanıyor.

### Diğer İyileştirmeler ve Hata Düzeltmeleri

- Uygulama fiyatının ve ilgili bilgilerin bazı durumlarda 'Hakkında' sekmesinde yanlış görüntülendiği bir sorun düzeltildi.
- Akıcı kaydırmayı ekran yenileme hızıyla senkronize etme mekanizmasının birden fazla ekran kullanılırken düzgün çalışmadığı bir sorun düzeltildi.
- Perde arkasında birçok küçük temizlik ve iyileştirme.

---

Ayrıca önceki sürüm [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2)'ye de göz at.