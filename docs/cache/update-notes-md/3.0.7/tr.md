Mac Mouse Fix **3.0.7** birkaç önemli hatayı gideriyor.

### Hata Düzeltmeleri

- Uygulama **eski macOS sürümlerinde** tekrar çalışıyor (macOS 10.15 Catalina ve macOS 11 Big Sur)
    - Mac Mouse Fix 3.0.6, bu macOS sürümlerinde etkinleştirilemiyordu çünkü Mac Mouse Fix 3.0.6'da tanıtılan geliştirilmiş 'Geri' ve 'İleri' özelliği, mevcut olmayan macOS sistem API'lerini kullanmaya çalışıyordu.
- **'Geri' ve 'İleri'** özelliğiyle ilgili sorunlar düzeltildi
    - Mac Mouse Fix 3.0.6'da tanıtılan geliştirilmiş 'Geri' ve 'İleri' özelliği artık kullandığın uygulamada geri ve ileri gitmek için hangi tuş basışlarını simüle edeceğini macOS'a sormak için her zaman 'ana iş parçacığını' kullanacak. \
    Bu, bazı durumlarda çökmeleri ve güvenilmez davranışları önleyebilir.
- **Ayarların rastgele sıfırlanması** hatasının düzeltilmesi denendi (Şu [GitHub Sorunlarına](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22) bakın)
    - Mac Mouse Fix için yapılandırma dosyasını yükleyen kodu daha sağlam olacak şekilde yeniden yazdım. Nadir macOS dosya sistemi hataları oluştuğunda, eski kod bazen yapılandırma dosyasının bozuk olduğunu yanlışlıkla düşünüp varsayılana sıfırlayabiliyordu.
- **Kaydırmanın durması** hatasının olasılığı azaltıldı
     - Bu hata, muhtemelen başka sorunlara yol açacak daha derin değişiklikler olmadan tam olarak çözülemiyor. \
      Ancak şimdilik, kaydırma sisteminde 'kilitlenme'nin gerçekleşebileceği zaman aralığını azalttım, bu da en azından bu hatayla karşılaşma olasılığını düşürmeli. Bu aynı zamanda kaydırmayı biraz daha verimli hale getiriyor.
    - Bu hatanın benzer belirtileri var – ancak bence farklı bir temel nedeni var – geçen sürüm 3.0.6'da ele alınan 'Kaydırma Aralıklı Olarak Duruyor' hatasından.
    - (Teşhisler için Joonas'a teşekkürler!)

Hataları bildirdiğiniz için hepinize teşekkürler!

---

Ayrıca önceki sürüm [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6)'ya da göz atın.