Mac Mouse Fix **3.0.2** membawa beberapa peningkatan, termasuk **pengguliran yang lebih halus**, terjemahan yang lebih baik, dan banyak lagi!

### Pengguliran

- Sekarang Anda dapat menghentikan animasi gulir dengan menggulir satu langkah ke arah berlawanan. Ini memungkinkan Anda untuk **'melempar'** dan **'menangkap halaman'** saat menggunakan 'Kehalusan: Tinggi', mirip dengan Trackpad.
- Mac Mouse Fix sekarang mengirim event gulir lebih awal dalam siklus penyegaran tampilan, memberi aplikasi lebih banyak waktu untuk memproses event gulir dan menampilkan pengguliran dengan halus. Ini **meningkatkan framerate**, terutama pada situs web kompleks seperti YouTube.com.
- Meningkatkan responsivitas pengaturan 'Kehalusan: Tinggi', membuat pengguliran lebih mudah dikontrol.
- Menyempurnakan mekanisme yang diperkenalkan di 3.0.1 di mana kecepatan animasi menjadi lebih cepat saat Anda menggerakkan roda gulir lebih cepat ketika menggunakan 'Kehalusan: Regular'. Di 3.0.2 percepatan animasi akan terlihat lebih konsisten dan dapat diprediksi, membuatnya lebih nyaman di mata sambil memberikan kontrol yang baik.
- Memperbaiki masalah di mana kecepatan pengguliran terlalu lambat, terutama saat menggunakan opsi 'Presisi'. Masalah ini diperkenalkan di 3.0.1. Terima kasih kepada @V-Coba yang telah menarik perhatian pada masalah ini di [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
- Meningkatkan perilaku di dalam browser Arc saat menggunakan 'Klik dan Gulir' untuk 'Perbesar atau Perkecil'.

### Lokalisasi

- Memperbarui terjemahan 🇻🇳 Vietnam. Kredit untuk @nghlt!
- Meningkatkan beberapa terjemahan 🇩🇪 Jerman.
- Teks di dalam Mac Mouse Fix yang tidak memiliki terjemahan untuk bahasa saat ini sekarang akan menampilkan nilai placeholder alih-alih kosong. Ini akan membuat navigasi aplikasi lebih mudah dipahami ketika ada terjemahan yang hilang.

### Lainnya

- Mac Mouse Fix sekarang akan menampilkan notifikasi dengan tautan ke [panduan ini](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) kepada pengguna yang mungkin mengalami bug di macOS 13 Ventura dan versi selanjutnya yang dapat mencegah Mac Mouse Fix diaktifkan.
- Mengubah pengaturan default untuk mouse dengan 3 tombol. Pengaturan default tidak lagi menampilkan aksi 'Klik dan Gulir' untuk Tombol Roda Gulir, karena itu cukup sulit dilakukan. Sebagai gantinya, pengaturan default sekarang menampilkan aksi 'Tahan' dan 'Klik Ganda'.
- Menambahkan tooltip ke ikon Mac Mouse Fix di tab Tentang. Ini memberi tahu Anda cara menampilkan file konfigurasi Mac Mouse Fix di Finder.
- Banyak perbaikan dan peningkatan di balik layar.

---

Lihat juga rilis sebelumnya [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).