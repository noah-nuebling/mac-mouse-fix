Ayrıca [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)'te tanıtılan **güzel değişikliklere** de göz atın!

---

**3.0.0 Beta 5**, macOS 13 Ventura'da bazı **fareler** ile **uyumluluğu** geri getiriyor ve birçok uygulamada **kaydırmayı düzeltiyor**.
Ayrıca çeşitli küçük düzeltmeler ve kullanım kolaylığı iyileştirmeleri içeriyor.

İşte **tüm yenilikler**:

### Fare

- Terminal ve diğer uygulamalarda kaydırma düzeltildi! GitHub Sorunu [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413)'e bakın.
- Güvenilmez Apple API'leri yerine düşük seviyeli çözümler kullanarak macOS 13 Ventura'da bazı farelerle olan uyumsuzluk sorunu giderildi. Umarım bu yeni sorunlara yol açmaz - eğer açarsa bana bildirin! Maria ve GitHub kullanıcısı [samiulhsnt](https://github.com/samiulhsnt)'ye bunu çözmemize yardımcı oldukları için özel teşekkürler! Daha fazla bilgi için GitHub Sorunu [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424)'e bakın.
- Fare Düğmesi 1 veya 2'ye tıklarken artık CPU kullanılmayacak. Diğer düğmelere tıklarken CPU kullanımı biraz azaltıldı.
    - Bu bir "Hata Ayıklama Sürümü" olduğundan, bu betada düğmelere tıklarken CPU kullanımı final sürüme göre yaklaşık 10 kat daha yüksek olabilir
- Mac Mouse Fix'in "Pürüzsüz Kaydırma" ve "Kaydır & Gezin" özellikleri için kullanılan trackpad kaydırma simülasyonu artık daha da hassas. Bu bazı durumlarda daha iyi davranışlara yol açabilir.

### Arayüz

- Mac Mouse Fix'in eski bir sürümünden güncelleme sonrası Erişilebilirlik Erişimi verme sorunları otomatik olarak düzeltiliyor. [2.2.2 Sürüm Notları](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2)'nda açıklanan değişiklikleri benimsiyor.
- "Erişilebilirlik Erişimi Ver" ekranına "İptal" düğmesi eklendi
- Mac Mouse Fix'in yeni bir sürümünü yükledikten sonra, yeni sürümün eski "Mac Mouse Fix Helper" sürümüne bağlanması nedeniyle yapılandırmanın düzgün çalışmadığı bir sorun düzeltildi. Artık Mac Mouse Fix eski "Mac Mouse Fix Helper"a bağlanmayacak ve gerektiğinde eski sürümü otomatik olarak devre dışı bırakacak.
- Sistemde başka bir Mac Mouse Fix sürümünün bulunması nedeniyle Mac Mouse Fix'in düzgün şekilde etkinleştirilememesi durumunda kullanıcıya sorunu nasıl düzelteceğine dair talimatlar veriliyor. Bu sorun yalnızca macOS Ventura'da ortaya çıkıyor.
- "Erişilebilirlik Erişimi Ver" ekranındaki davranış ve animasyonlar iyileştirildi
- Mac Mouse Fix etkinleştirildiğinde ön plana getirilecek. Bu, Mac Mouse Fix'i Sistem Ayarları > Genel > Oturum Açma Öğeleri altında devre dışı bırakıldıktan sonra etkinleştirdiğinizde olduğu gibi bazı durumlarda arayüz etkileşimlerini iyileştirir.
- "Erişilebilirlik Erişimi Ver" ekranındaki arayüz metinleri iyileştirildi
- Mac Mouse Fix Sistem Ayarları'nda devre dışıyken etkinleştirmeye çalışırken görünen arayüz metinleri iyileştirildi
- Almanca bir arayüz metni düzeltildi

### Altyapı

- "Mac Mouse Fix" ve gömülü "Mac Mouse Fix Helper"ın derleme numaraları artık senkronize edildi. Bu, "Mac Mouse Fix"in yanlışlıkla eski "Mac Mouse Fix Helper" sürümlerine bağlanmasını önlemek için kullanılıyor.
- Uygulamayı ilk kez başlatırken lisansınız ve deneme sürenizle ilgili bazı verilerin bazen yanlış görüntülenmesi sorunu, başlangıç yapılandırmasından önbellek verilerini kaldırarak düzeltildi
- Proje yapısı ve kaynak kodunda çok sayıda temizlik yapıldı
- Hata ayıklama mesajları iyileştirildi

---

### Nasıl Yardımcı Olabilirsiniz

**Fikirlerinizi**, **sorunlarınızı** ve **geri bildirimlerinizi** paylaşarak yardımcı olabilirsiniz!

**Fikirlerinizi** ve **sorunlarınızı** paylaşmak için en iyi yer [Geri Bildirim Asistanı](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report)'dır.
**Hızlı**, yapılandırılmamış geri bildirim vermek için en iyi yer [Geri Bildirim Tartışması](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366)'dır.

Bu yerlere uygulama içinden "**ⓘ Hakkında**" sekmesinden de erişebilirsiniz.

Mac Mouse Fix'i daha iyi hale getirmeye yardımcı olduğunuz için **teşekkürler**! 💙💛❤️