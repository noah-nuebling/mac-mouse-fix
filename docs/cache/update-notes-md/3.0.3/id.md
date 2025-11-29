Mac Mouse Fix **3.0.3** siap untuk macOS 15 Sequoia. Versi ini juga memperbaiki beberapa masalah stabilitas dan memberikan beberapa peningkatan kecil.

### Dukungan macOS 15 Sequoia

Aplikasi sekarang berfungsi dengan baik di macOS 15 Sequoia!

- Sebagian besar animasi UI rusak di macOS 15 Sequoia. Sekarang semuanya berfungsi dengan baik lagi!
- Kode sumber sekarang dapat di-build di macOS 15 Sequoia. Sebelumnya, ada masalah dengan kompiler Swift yang mencegah aplikasi di-build.

### Mengatasi crash saat scroll

Sejak Mac Mouse Fix 3.0.2 ada [beberapa laporan](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) tentang Mac Mouse Fix yang secara berkala menonaktifkan dan mengaktifkan dirinya sendiri saat scrolling. Ini disebabkan oleh crash pada aplikasi latar belakang 'Mac Mouse Fix Helper'. Pembaruan ini mencoba memperbaiki crash tersebut, dengan perubahan berikut:

- Mekanisme scrolling akan mencoba pulih dan terus berjalan alih-alih crash, ketika menemui kasus khusus yang tampaknya menyebabkan crash ini.
- Saya mengubah cara penanganan kondisi tak terduga dalam aplikasi secara lebih umum: Alih-alih selalu langsung crash, aplikasi sekarang akan mencoba pulih dari kondisi tak terduga dalam banyak kasus.
    
    - Perubahan ini berkontribusi pada perbaikan crash scroll yang dijelaskan di atas. Ini mungkin juga mencegah crash lainnya.
  
Catatan: Saya tidak pernah bisa mereproduksi crash ini di mesin saya, dan saya masih tidak yakin apa penyebabnya, tetapi berdasarkan laporan yang saya terima, pembaruan ini seharusnya mencegah crash apa pun. Jika kamu masih mengalami crash saat scrolling atau jika kamu *pernah* mengalami crash di 3.0.2, akan sangat berharga jika kamu membagikan pengalaman dan data diagnostik di GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Ini akan membantu saya memahami masalahnya dan meningkatkan Mac Mouse Fix. Terima kasih!

### Mengatasi scroll yang tersendat

Di 3.0.2 saya membuat perubahan pada cara Mac Mouse Fix mengirim event scroll ke sistem dalam upaya mengurangi scroll yang tersendat yang kemungkinan disebabkan oleh masalah dengan API VSync Apple.

Namun, setelah pengujian dan umpan balik yang lebih ekstensif, tampaknya mekanisme baru di 3.0.2 membuat scrolling lebih halus dalam beberapa skenario tetapi lebih tersendat di skenario lainnya. Terutama di Firefox tampaknya jauh lebih buruk. \
Secara keseluruhan, tidak jelas bahwa mekanisme baru benar-benar meningkatkan scroll yang tersendat secara menyeluruh. Selain itu, ini mungkin berkontribusi pada crash scroll yang dijelaskan di atas.

Itulah mengapa saya menonaktifkan mekanisme baru dan mengembalikan mekanisme VSync untuk event scroll kembali seperti di Mac Mouse Fix 3.0.0 dan 3.0.1.

Lihat GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) untuk info lebih lanjut.

### Pengembalian dana

Saya minta maaf atas masalah terkait perubahan scrolling di 3.0.1 dan 3.0.2. Saya sangat meremehkan masalah yang akan muncul dengan itu, dan saya lambat dalam mengatasi masalah ini. Saya akan melakukan yang terbaik untuk belajar dari pengalaman ini dan lebih berhati-hati dengan perubahan seperti itu di masa depan. Saya juga ingin menawarkan pengembalian dana kepada siapa pun yang terdampak. Cukup klik [di sini](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) jika kamu tertarik.

### Mekanisme pembaruan yang lebih pintar

Perubahan ini dibawa dari Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) dan [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Lihat catatan rilis mereka untuk mempelajari lebih lanjut tentang detailnya. Berikut ringkasannya:

- Ada mekanisme baru yang lebih pintar yang memutuskan pembaruan mana yang akan ditampilkan kepada pengguna.
- Beralih dari menggunakan framework pembaruan Sparkle 1.26.0 ke Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) terbaru.
- Jendela yang ditampilkan aplikasi untuk memberi tahu kamu bahwa versi baru Mac Mouse Fix tersedia sekarang mendukung JavaScript, yang memungkinkan format catatan pembaruan yang lebih bagus.

### Peningkatan & Perbaikan Bug Lainnya

- Memperbaiki masalah di mana harga aplikasi dan info terkait akan ditampilkan dengan tidak benar di tab 'About' dalam beberapa kasus.
- Memperbaiki masalah di mana mekanisme untuk menyinkronkan smooth scrolling dengan refresh rate layar tidak berfungsi dengan baik saat menggunakan beberapa layar.
- Banyak pembersihan dan peningkatan kecil di balik layar.

---

Lihat juga rilis sebelumnya [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).