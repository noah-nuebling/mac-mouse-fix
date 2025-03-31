**ℹ️ Mac Mouse Fix 2 Kullanıcılarına Not**

Mac Mouse Fix 3'ün tanıtımıyla birlikte uygulamanın fiyatlandırma modeli değişti:

- **Mac Mouse Fix 2**\
%100 ücretsiz kalıyor ve desteklemeye devam edeceğim.\
Mac Mouse Fix 2'yi kullanmaya devam etmek için **bu güncellemeyi atla**. Mac Mouse Fix 2'nin en son sürümünü [buradan](https://redirect.macmousefix.com/?target=mmf2-latest) indirebilirsin.
- **Mac Mouse Fix 3**\
30 gün ücretsiz, sahip olmak için birkaç dolar ödemen gerekiyor.\
Mac Mouse Fix 3'ü edinmek için **şimdi güncelle**!

Mac Mouse Fix 3'ün fiyatlandırması ve özellikleri hakkında daha fazla bilgiyi [yeni web sitesinde](https://macmousefix.com/) bulabilirsin.

Mac Mouse Fix'i kullandığın için teşekkürler! :)

---

**ℹ️ Mac Mouse Fix 3 Alıcılarına Not**

Eğer yanlışlıkla artık ücretsiz olmadığını bilmeden Mac Mouse Fix 3'e güncellediysen, sana [para iadesi](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) teklif etmek isterim.

Mac Mouse Fix 2'nin son sürümü **tamamen ücretsiz** kalıyor ve [buradan](https://redirect.macmousefix.com/?target=mmf2-latest) indirebilirsin.

Rahatsızlık için özür dilerim ve umarım bu çözüm herkes için uygundur!

---

Mac Mouse Fix **3.0.3** macOS 15 Sequoia için hazır. Ayrıca bazı kararlılık sorunlarını düzeltiyor ve çeşitli küçük iyileştirmeler sunuyor.

### macOS 15 Sequoia desteği

Uygulama artık macOS 15 Sequoia'da düzgün çalışıyor!

- macOS 15 Sequoia'da çoğu UI animasyonu bozuktu. Artık her şey tekrar düzgün çalışıyor!
- Kaynak kodu artık macOS 15 Sequoia'da derlenebiliyor. Önceden, Swift derleyicisiyle ilgili sorunlar uygulamanın derlenmesini engelliyordu.

### Kaydırma çökmelerinin ele alınması

Mac Mouse Fix 3.0.2'den bu yana, kaydırma sırasında Mac Mouse Fix'in periyodik olarak kendini devre dışı bırakıp yeniden etkinleştirdiğine dair [birden fazla rapor](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) geldi. Bu, 'Mac Mouse Fix Helper' arka plan uygulamasının çökmesinden kaynaklanıyordu. Bu güncelleme, aşağıdaki değişikliklerle bu çökmeleri düzeltmeye çalışıyor:

- Kaydırma mekanizması, bu çökmelere neden olduğu düşünülen uç durumla karşılaştığında çökmek yerine kurtulmaya ve çalışmaya devam etmeye çalışacak.
- Uygulamada beklenmeyen durumların ele alınış şeklini daha genel olarak değiştirdim: Artık hemen çökmek yerine, uygulama birçok durumda beklenmeyen durumlardan kurtulmaya çalışacak.

    - Bu değişiklik, yukarıda açıklanan kaydırma çökmelerinin düzeltilmesine katkıda bulunuyor. Ayrıca diğer çökmeleri de önleyebilir.

Not: Bu çökmeleri kendi makinemde hiç tekrarlayamadım ve hala neyin sebep olduğundan emin değilim, ancak aldığım raporlara dayanarak bu güncelleme herhangi bir çökmeyi önleyecektir. Eğer hala kaydırma sırasında çökmeler yaşıyorsanız veya 3.0.2 sürümünde çökmeler yaşadıysanız, deneyiminizi ve tanılama verilerinizi GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988)'de paylaşmanız değerli olacaktır. Bu, sorunu anlamama ve Mac Mouse Fix'i geliştirmeme yardımcı olacaktır. Teşekkürler!

### Kaydırma takılmalarının ele alınması

3.0.2'de, Apple'ın VSync API'lerinden kaynaklanan kaydırma takılmalarını azaltmak amacıyla Mac Mouse Fix'in sisteme kaydırma olaylarını gönderme şeklinde değişiklikler yaptım.

Ancak, daha kapsamlı testler ve geri bildirimler sonrasında, 3.0.2'deki yeni mekanizmanın bazı senaryolarda kaydırmayı daha pürüzsüz hale getirirken diğerlerinde daha takılmalı hale getirdiği görüldü. Özellikle Firefox'ta belirgin şekilde daha kötü olduğu görüldü.\
Genel olarak, yeni mekanizmanın kaydırma takılmalarını gerçekten iyileştirdiği net değildi. Ayrıca, yukarıda açıklanan kaydırma çökmelerine katkıda bulunmuş olabilir.

Bu nedenle yeni mekanizmayı devre dışı bıraktım ve kaydırma olayları için VSync mekanizmasını Mac Mouse Fix 3.0.0 ve 3.0.1'deki haline geri döndürdüm.

Daha fazla bilgi için GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875)'e bakın.

### Para İadesi

3.0.1 ve 3.0.2'deki kaydırma değişiklikleriyle ilgili sorunlar için özür dilerim. Bunlarla ilgili ortaya çıkacak sorunları büyük ölçüde hafife aldım ve bu sorunları ele almakta yavaş kaldım. Bu deneyimden ders çıkarmaya ve gelecekte bu tür değişikliklerde daha dikkatli olmaya çalışacağım. Ayrıca etkilenen herkese para iadesi teklif etmek istiyorum. İlgileniyorsanız [buraya](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) tıklamanız yeterli.

### Daha akıllı güncelleme mekanizması

Bu değişiklikler Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) ve [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5)'ten aktarıldı. Detaylar için onların sürüm notlarına göz atın. İşte bir özet:

- Kullanıcıya hangi güncellemeyi göstereceğine karar veren yeni, daha akıllı bir mekanizma var.
- Sparkle 1.26.0 güncelleme çerçevesinden en son Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3)'e geçiş yapıldı.
- Uygulamanın Mac Mouse Fix'in yeni bir sürümünün mevcut olduğunu bildirmek için gösterdiği pencere artık JavaScript'i destekliyor, bu da güncelleme notlarının daha güzel formatlanmasına olanak tanıyor.

### Diğer İyileştirmeler ve Hata Düzeltmeleri

- Bazı durumlarda 'Hakkında' sekmesinde uygulama fiyatı ve ilgili bilgilerin yanlış görüntülenmesi sorunu düzeltildi.
- Birden fazla ekran kullanırken pürüzsüz kaydırmanın ekran yenileme hızıyla senkronize edilme mekanizmasının düzgün çalışmaması sorunu düzeltildi.
- Birçok küçük altyapı temizliği ve iyileştirmesi yapıldı.

---

Ayrıca önceki sürüm [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2)'ye de göz atın.