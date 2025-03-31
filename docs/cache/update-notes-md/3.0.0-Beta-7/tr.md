Ayrıca [3.0.0 Beta 6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-6)'da tanıtılan **harika geliştirmelere** de göz atın!


---

**3.0.0 Beta 7** birkaç küçük iyileştirme ve hata düzeltmesi getiriyor.

İşte tüm yenilikler:

**İyileştirmeler**

- **Korece çeviriler** eklendi. @jeongtae'ye çok teşekkürler! (Kendisini [GitHub](https://github.com/jeongtae)'da bulabilirsiniz)
- 'Yumuşaklık: Yüksek' seçeneğiyle **kaydırma** işlemini, kaydırma tekerleğini hareket ettirirken ani hız değişimleri yerine hızı kademeli olarak değiştirerek **daha da pürüzsüz** hale getirdik. Bu, kaydırmayı gözlerinizle takip etmeyi biraz daha kolay ve pürüzsüz hale getirirken tepkisellikten ödün vermeyecek. 'Yumuşaklık: Yüksek' ile kaydırma artık yaklaşık %30 daha fazla CPU kullanıyor, benim bilgisayarımda sürekli kaydırma sırasında CPU kullanımı %1.2'den %1.6'ya çıktı. Yani kaydırma hala oldukça verimli ve umarım bu kimse için fark yaratmaz. Bu özelliğe ilham veren ve özelliği uygulamama yardımcı olan 'Scroll Monitor'ü için [MOS](https://mos.caldis.me/)'a çok teşekkürler.
- Mac Mouse Fix artık **tüm kaynaklardan gelen düğme girişlerini işliyor**. Daha önce, Mac Mouse Fix yalnızca tanıdığı farelerden gelen girişleri işliyordu. Bunun Hackintosh kullanırken olduğu gibi bazı uç durumlarda belirli farelerle uyumluluğa yardımcı olabileceğini düşünüyorum, ancak aynı zamanda Mac Mouse Fix'in diğer uygulamalardan yapay olarak üretilen düğme girişlerini algılamasına neden olacak ve bu da başka uç durumlarda sorunlara yol açabilir. Bu sizin için herhangi bir soruna yol açarsa bana bildirin, gelecek güncellemelerde bu konuyu ele alacağım.
- 'Masaüstü ve Launchpad' için 'Tıkla ve Kaydır' ve 'Masaüstü Alanları Arasında Hareket' için 'Tıkla ve Kaydır' hareketlerinin hissiyatı ve inceliği geliştirildi.
- Artık **bildirimlerin gösterilme süresini** hesaplarken bir dilin bilgi yoğunluğu dikkate alınıyor. Daha önce, Çince veya Korece gibi yüksek bilgi yoğunluğuna sahip dillerde bildirimler çok kısa süre görünür kalıyordu.
- **Masaüstü Alanları** arasında hareket etmek, **Mission Control**'ü açmak veya **Uygulama Exposé**'sini açmak için **farklı hareketler** etkinleştirildi. Beta 6'da, bu eylemlere sadece 'Tıkla ve Sürükle' hareketiyle erişilebilmesini sağlamıştım - insanların bu eylemlere başka yollarla erişebilmeyi gerçekten önemseyip önemsemediklerini görmek için bir deney olarak. Bazılarının önemsediği anlaşılıyor, bu yüzden şimdi bu eylemlere basit bir düğme 'Tıklaması' veya 'Tıkla ve Kaydır' ile erişmek tekrar mümkün.
- 'Tıkla ve Kaydır' hareketiyle **Döndürme** yapılması mümkün hale getirildi.
- **Trackpad Simülasyonu** seçeneğinin bazı senaryolarda çalışma şekli **iyileştirildi**. Örneğin Mail'de bir mesajı silmek için yatay kaydırma yaparken, mesajın hareket ettiği yön artık tersine çevrildi, bu da umarım çoğu kişi için daha doğal ve tutarlı hissedilir.
- **Birincil Tıklama** veya **İkincil Tıklama** olarak **yeniden eşleme** özelliği eklendi. Bunu en sevdiğim farenin sağ tuşu bozulduğu için ekledim. Bu seçenekler varsayılan olarak gizlidir. Bir eylem seçerken Option tuşunu basılı tutarak bunları görebilirsiniz.
  - Şu anda Çince ve Korece çevirileri eksik, bu özellikler için çeviri katkısında bulunmak isterseniz çok memnun oluruz!

**Hata Düzeltmeleri**

- 'Mission Control ve Masaüstü Alanları' için **'Tıkla ve Sürükle' yönünün** Sistem Ayarları'nda 'Doğal kaydırma' seçeneğini hiç değiştirmemiş kişiler için **ters** olduğu bir hata düzeltildi. Artık Mac Mouse Fix'teki 'Tıkla ve Sürükle' hareketlerinin yönü her zaman Trackpad veya Magic Mouse'unuzdaki hareketlerin yönüyle eşleşmeli. 'Tıkla ve Sürükle' yönünü Sistem Ayarları'nı takip etmek yerine ayrı bir seçenekle tersine çevirmek istiyorsanız bana bildirin.
- Bazı kullanıcılar için **ücretsiz günlerin** çok hızlı **sayıldığı** bir hata düzeltildi. Bu durumdan etkilendiyseniz bana bildirin, ne yapabileceğime bakacağım.
- macOS Sonoma'da sekme çubuğunun düzgün görüntülenmemesi sorunu düzeltildi.
- Launchpad'i açmak için 'Tıkla ve Kaydır' kullanırken 'macOS' kaydırma hızını kullanmanın neden olduğu takılmalar düzeltildi.
- 'Mac Mouse Fix Helper' uygulamasının (Mac Mouse Fix etkinken arka planda çalışan) bir klavye kısayolunu kaydederken bazen çökmesi sorunu düzeltildi.
- Mac Mouse Fix'in [MiddleClick-Sonoma](https://github.com/artginzburg/MiddleClick-Sonoma) tarafından üretilen yapay olayları algılamaya çalışırken çökmesine neden olan bir hata düzeltildi.
- 'Varsayılanlara Geri Dön...' iletişim kutusunda bazı farelerin adının üreticiyi iki kez içerdiği bir sorun düzeltildi.
- Bilgisayar yavaşken 'Mission Control ve Masaüstü Alanları' için 'Tıkla ve Sürükle'nin takılı kalma olasılığı azaltıldı.
- Arayüz metinlerinde 'Force Touch' yerine 'Force click' kullanımı düzeltildi.
- Belirli yapılandırmalarda, 'Tıkla ve Kaydır' ile Launchpad'i açma veya Masaüstünü gösterme işleminde, geçiş animasyonu devam ederken düğmeyi bırakırsanız çalışmama sorunu düzeltildi.

**Diğer**

- Çeşitli arka plan iyileştirmeleri, kararlılık iyileştirmeleri, arka plan temizliği ve daha fazlası.

## Nasıl Yardımcı Olabilirsiniz

**Fikirlerinizi**, **sorunlarınızı** ve **geri bildirimlerinizi** paylaşarak yardımcı olabilirsiniz!

**Fikirlerinizi** ve **sorunlarınızı** paylaşmak için en iyi yer [Geri Bildirim Asistanı](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
**Hızlı** yapılandırılmamış geri bildirim vermek için en iyi yer [Geri Bildirim Tartışması](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Bu yerlere uygulamanın içinden '**ⓘ Hakkında**' sekmesinden de erişebilirsiniz.

Mac Mouse Fix'i daha iyi hale getirmeye yardımcı olduğunuz için **teşekkürler**! 😎:)