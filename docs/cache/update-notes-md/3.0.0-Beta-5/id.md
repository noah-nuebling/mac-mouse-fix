Lihat juga **perubahan keren** yang diperkenalkan di [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** mengembalikan **kompatibilitas** dengan beberapa **mouse** di macOS 13 Ventura dan **memperbaiki scrolling** di banyak aplikasi.
Juga mencakup beberapa perbaikan kecil dan peningkatan kualitas lainnya.

Berikut **semua yang baru**:

### Mouse

- Memperbaiki scrolling di Terminal dan aplikasi lainnya! Lihat GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Memperbaiki ketidakcocokan dengan beberapa mouse di macOS 13 Ventura dengan beralih dari penggunaan Apple API yang tidak dapat diandalkan ke hack tingkat rendah. Semoga ini tidak menimbulkan masalah baru - beri tahu saya jika terjadi! Terima kasih khusus kepada Maria dan pengguna GitHub [samiulhsnt](https://github.com/samiulhsnt) yang membantu memecahkan masalah ini! Lihat GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) untuk informasi lebih lanjut.
- Tidak akan menggunakan CPU saat mengklik Tombol Mouse 1 atau 2 lagi. Sedikit menurunkan penggunaan CPU saat mengklik tombol lainnya.
    - Ini adalah "Debug Build" sehingga penggunaan CPU bisa sekitar 10 kali lebih tinggi saat mengklik tombol di beta ini dibandingkan dengan rilis final
- Simulasi scrolling trackpad yang digunakan untuk fitur "Smooth Scrolling" dan "Scroll & Navigate" Mac Mouse Fix sekarang lebih akurat. Ini mungkin menghasilkan perilaku yang lebih baik dalam beberapa situasi.

### UI

- Secara otomatis memperbaiki masalah pemberian Akses Aksesibilitas setelah memperbarui dari versi Mac Mouse Fix yang lebih lama. Mengadopsi perubahan yang dijelaskan dalam [Catatan Rilis 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Menambahkan tombol "Batal" ke layar "Berikan Akses Aksesibilitas"
- Memperbaiki masalah di mana konfigurasi Mac Mouse Fix tidak berfungsi dengan baik setelah menginstal versi baru Mac Mouse Fix, karena versi baru akan terhubung ke versi lama "Mac Mouse Fix Helper". Sekarang, Mac Mouse Fix tidak akan terhubung ke "Mac Mouse Fix Helper" lama lagi dan menonaktifkan versi lama secara otomatis bila diperlukan.
- Memberikan instruksi kepada pengguna tentang cara memperbaiki masalah di mana Mac Mouse Fix tidak dapat diaktifkan dengan benar karena versi Mac Mouse Fix lain ada di sistem. Masalah ini hanya terjadi di macOS Ventura.
- Memperhalus perilaku dan animasi di layar "Berikan Akses Aksesibilitas"
- Mac Mouse Fix akan dibawa ke latar depan saat diaktifkan. Ini meningkatkan interaksi UI dalam beberapa situasi seperti ketika Anda mengaktifkan Mac Mouse Fix setelah dinonaktifkan di Pengaturan Sistem > Umum > Item Login.
- Meningkatkan string UI di layar "Berikan Akses Aksesibilitas"
- Meningkatkan string UI yang muncul saat mencoba mengaktifkan Mac Mouse Fix sementara dinonaktifkan di Pengaturan Sistem
- Memperbaiki string UI bahasa Jerman

### Di Balik Layar

- Nomor build "Mac Mouse Fix" dan "Mac Mouse Fix Helper" yang tertanam sekarang disinkronkan. Ini digunakan untuk mencegah "Mac Mouse Fix" tidak sengaja terhubung ke versi lama "Mac Mouse Fix Helper".
- Memperbaiki masalah di mana beberapa data seputar lisensi dan periode uji coba terkadang ditampilkan secara tidak benar saat memulai aplikasi untuk pertama kali dengan menghapus data cache dari konfigurasi awal
- Banyak pembersihan struktur proyek dan kode sumber
- Meningkatkan pesan debug

---

### Bagaimana Anda Dapat Membantu

Anda dapat membantu dengan berbagi **ide**, **masalah** dan **umpan balik** Anda!

Tempat terbaik untuk berbagi **ide** dan **masalah** Anda adalah [Asisten Umpan Balik](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Tempat terbaik untuk memberikan umpan balik **cepat** yang tidak terstruktur adalah [Diskusi Umpan Balik](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Anda juga dapat mengakses tempat-tempat ini dari dalam aplikasi di tab "**ⓘ Tentang**".

**Terima kasih** telah membantu membuat Mac Mouse Fix lebih baik! 💙💛❤️