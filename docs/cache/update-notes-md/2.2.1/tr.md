Mac Mouse Fix **2.2.1**, diğer değişikliklerin yanı sıra **macOS Ventura için tam destek** sunuyor.

### Ventura desteği!
Mac Mouse Fix artık macOS 13 Ventura'yı tam olarak destekliyor ve sistemle uyumlu çalışıyor.
GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297)'de Ventura desteğine yardımcı olan [@chamburr](https://github.com/chamburr)'a özel teşekkürler.

Değişiklikler şunları içeriyor:

- Erişilebilirlik İzinleri arayüzü yeni Ventura Sistem Ayarları'nı yansıtacak şekilde güncellendi
- Mac Mouse Fix, Ventura'nın yeni **Sistem Ayarları > Başlangıç Öğeleri** menüsünde düzgün şekilde görüntülenecek
- Mac Mouse Fix, **Sistem Ayarları > Başlangıç Öğeleri** altında devre dışı bırakıldığında uygun şekilde tepki verecek

### Eski macOS sürümleri için desteğin sonlandırılması

Ne yazık ki Apple, macOS 13 Ventura'dan geliştirme yaparken sadece macOS 10.13 **High Sierra ve sonrası** için geliştirme yapmanıza izin veriyor.

Bu nedenle **minimum desteklenen sürüm** 10.11 El Capitan'dan 10.13 High Sierra'ya yükseldi.

### Hata düzeltmeleri

- Mac Mouse Fix'in bazı **çizim tabletlerinin** kaydırma davranışını değiştirdiği sorunu düzeltildi. GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)'a bakın.
- 'A' tuşunu içeren **klavye kısayollarının** kaydedilemediği sorunu düzeltildi. GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275) düzeltildi.
- Standart olmayan klavye düzeni kullanırken bazı **düğme yeniden eşlemelerinin** düzgün çalışmadığı sorunu düzeltildi.
- '**Uygulamaya özel ayarlar**'da 'Bundle ID'si olmayan bir uygulama eklenmeye çalışılırken oluşan çökme düzeltildi. GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289) ile ilgili yardımcı olabilir.
- '**Uygulamaya Özel ayarlar**'a ismi olmayan uygulamalar eklenmeye çalışılırken oluşan çökme düzeltildi. GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241) çözüldü. Sorunu çözmede çok yardımcı olan [jeongtae](https://github.com/jeongtae)'ye özel teşekkürler!
- Daha fazla küçük hata düzeltmesi ve altyapı iyileştirmesi.