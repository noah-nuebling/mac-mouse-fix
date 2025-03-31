Mac Mouse Fix **2.2.1** menyediakan **dukungan penuh untuk macOS Ventura** beserta perubahan lainnya.

### Dukungan Ventura!
Mac Mouse Fix kini sepenuhnya mendukung dan terasa native di macOS 13 Ventura.
Terima kasih khusus kepada [@chamburr](https://github.com/chamburr) yang membantu dukungan Ventura di GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Perubahan meliputi:

- Memperbarui UI untuk memberikan Akses Aksesibilitas agar sesuai dengan System Settings Ventura yang baru
- Mac Mouse Fix akan ditampilkan dengan benar di menu **System Settings > Login Items** Ventura yang baru
- Mac Mouse Fix akan bereaksi dengan tepat saat dinonaktifkan di **System Settings > Login Items**

### Menghentikan dukungan untuk versi macOS lama

Sayangnya, Apple hanya mengizinkan pengembangan _untuk_ macOS 10.13 **High Sierra dan yang lebih baru** saat mengembangkan _dari_ macOS 13 Ventura.

Jadi **versi minimum yang didukung** meningkat dari 10.11 El Capitan ke 10.13 High Sierra.

### Perbaikan bug

- Memperbaiki masalah di mana Mac Mouse Fix mengubah perilaku pengguliran beberapa **tablet gambar**. Lihat GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Memperbaiki masalah di mana **pintasan keyboard** yang mengandung tombol 'A' tidak bisa direkam. Memperbaiki GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Memperbaiki masalah di mana beberapa **pemetaan ulang tombol** tidak berfungsi dengan baik saat menggunakan tata letak keyboard non-standar.
- Memperbaiki crash di '**Pengaturan khusus aplikasi**' saat mencoba menambahkan aplikasi tanpa 'Bundle ID'. Mungkin membantu dengan GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Memperbaiki crash saat mencoba menambahkan aplikasi yang tidak memiliki nama ke '**Pengaturan Khusus Aplikasi**'. Menyelesaikan GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Terima kasih khusus kepada [jeongtae](https://github.com/jeongtae) yang sangat membantu dalam menemukan masalahnya!
- Lebih banyak perbaikan bug kecil dan peningkatan di balik layar.