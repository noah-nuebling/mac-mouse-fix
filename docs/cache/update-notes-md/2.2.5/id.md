Mac Mouse Fix **2.2.5** memiliki peningkatan pada mekanisme pembaruan, dan siap untuk macOS 15 Sequoia!

### Kerangka pembaruan Sparkle baru

Mac Mouse Fix menggunakan kerangka pembaruan [Sparkle](https://sparkle-project.org/) untuk membantu memberikan pengalaman pembaruan yang hebat.

Dengan 2.2.5, Mac Mouse Fix beralih dari menggunakan Sparkle 1.26.0 ke Sparkle versi terbaru [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), yang memuat perbaikan keamanan, peningkatan lokalisasi, dan lainnya.

### Mekanisme pembaruan yang lebih cerdas

Ada mekanisme baru yang menentukan pembaruan mana yang akan ditampilkan kepada pengguna. Perilakunya berubah dalam cara berikut:

1. Setelah kamu melewati pembaruan **major** (seperti 2.2.5 -> 3.0.0), kamu tetap akan diberi tahu tentang pembaruan **minor** baru (seperti 2.2.5 -> 2.2.6).
    - Ini memungkinkan kamu untuk tetap menggunakan Mac Mouse Fix 2 sambil tetap menerima pembaruan, seperti yang dibahas di GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Alih-alih menampilkan pembaruan ke versi terbaru, Mac Mouse Fix sekarang akan menampilkan pembaruan ke versi pertama dari versi major terbaru.
    - Contoh: Jika kamu menggunakan MMF 2.2.5, dan MMF 3.4.5 adalah versi terbaru, aplikasi sekarang akan menampilkan versi pertama dari MMF 3 (3.0.0), bukan versi terbaru (3.4.5). Dengan cara ini, semua pengguna MMF 2.2.5 akan melihat changelog MMF 3.0.0 sebelum beralih ke MMF 3.
    - Diskusi:
        - Motivasi utama di balik ini adalah, awal tahun ini, banyak pengguna MMF 2 memperbarui langsung dari MMF 2 ke MMF 3.0.1, atau 3.0.2. Karena mereka tidak pernah melihat changelog 3.0.0, mereka melewatkan informasi tentang perubahan harga antara MMF 2 dan MMF 3 (MMF 3 tidak lagi 100% gratis). Jadi ketika MMF 3 tiba-tiba mengatakan mereka perlu membayar untuk terus menggunakan aplikasi, beberapa - yang bisa dimengerti - sedikit bingung dan kecewa.
        - Kerugian: Jika kamu hanya ingin memperbarui ke versi terbaru, sekarang kamu harus memperbarui dua kali dalam beberapa kasus. Ini sedikit tidak efisien, tapi seharusnya tetap hanya membutuhkan beberapa detik. Dan karena ini membuat perubahan antara versi major jauh lebih transparan, saya pikir ini adalah pertukaran yang masuk akal.

### Dukungan macOS 15 Sequoia

Mac Mouse Fix 2.2.5 akan bekerja dengan baik di macOS 15 Sequoia yang baru - sama seperti 2.2.4.

---

Lihat juga rilis sebelumnya [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Jika kamu mengalami masalah mengaktifkan Mac Mouse Fix setelah memperbarui, silakan periksa ['Panduan Mengaktifkan Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*