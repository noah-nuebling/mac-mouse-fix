Mac Mouse Fix **2.2.5**, güncelleme mekanizmasında iyileştirmeler içeriyor ve macOS 15 Sequoia için hazır!

### Yeni Sparkle güncelleme çerçevesi

Mac Mouse Fix, harika bir güncelleme deneyimi sunmak için [Sparkle](https://sparkle-project.org/) güncelleme çerçevesini kullanıyor.

2.2.5 ile birlikte Mac Mouse Fix, Sparkle 1.26.0'dan en son [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) sürümüne geçiş yapıyor. Bu sürüm güvenlik düzeltmeleri, yerelleştirme iyileştirmeleri ve daha fazlasını içeriyor.

### Daha akıllı güncelleme mekanizması

Kullanıcıya hangi güncellemenin gösterileceğine karar veren yeni bir mekanizma var. Davranış şu şekillerde değişti:

1. **Büyük** bir güncellemeyi (2.2.5 -> 3.0.0 gibi) atladıktan sonra, hala **küçük** güncellemeler (2.2.5 -> 2.2.6 gibi) hakkında bildirim alacaksınız.
    - Bu, GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962)'de tartışıldığı gibi, Mac Mouse Fix 2'de kalırken güncellemeleri almaya devam etmenizi sağlar.
2. En son sürüme güncelleme göstermek yerine, Mac Mouse Fix artık size en son ana sürümün ilk sürümüne güncellemeyi gösterecek.
    - Örnek: MMF 2.2.5 kullanıyorsanız ve MMF 3.4.5 en son sürümse, uygulama artık en son sürümü (3.4.5) değil, MMF 3'ün ilk sürümünü (3.0.0) gösterecek. Böylece tüm MMF 2.2.5 kullanıcıları, MMF 3'e geçmeden önce MMF 3.0.0 değişiklik günlüğünü görecek.
    - Tartışma:
        - Bunun arkasındaki ana motivasyon, bu yılın başlarında birçok MMF 2 kullanıcısının doğrudan MMF 2'den MMF 3.0.1 veya 3.0.2'ye güncellemesiydi. 3.0.0 değişiklik günlüğünü hiç görmedikleri için, MMF 2 ve MMF 3 arasındaki fiyatlandırma değişiklikleri (MMF 3'ün artık %100 ücretsiz olmaması) hakkındaki bilgileri kaçırdılar. Bu yüzden MMF 3 aniden uygulamayı kullanmaya devam etmek için ödeme yapmaları gerektiğini söylediğinde, bazıları - anlaşılır bir şekilde - biraz kafası karışmış ve üzülmüştü.
        - Dezavantaj: Sadece en son sürüme güncellemek istiyorsanız, artık bazı durumlarda iki kez güncelleme yapmanız gerekecek. Bu biraz verimsiz, ancak yine de sadece birkaç saniye sürmeli. Ve bu, ana sürümler arasındaki değişiklikleri çok daha şeffaf hale getirdiği için, mantıklı bir değiş tokuş olduğunu düşünüyorum.

### macOS 15 Sequoia desteği

Mac Mouse Fix 2.2.5, tıpkı 2.2.4 gibi, yeni macOS 15 Sequoia'da harika çalışacak.

---

Ayrıca önceki sürüm [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4)'e göz atın.

*Güncellemeden sonra Mac Mouse Fix'i etkinleştirmekte sorun yaşıyorsanız, lütfen ['Mac Mouse Fix'i Etkinleştirme' Kılavuzu](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861)'na göz atın.*