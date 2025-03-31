Mac Mouse Fix **3.0.1** membawa beberapa perbaikan bug dan peningkatan, beserta **bahasa baru**!

### Bahasa Vietnam telah ditambahkan!

Mac Mouse Fix kini tersedia dalam bahasa 🇻🇳 Vietnam. Terima kasih banyak kepada @nghlt [di GitHub](https://GitHub.com/nghlt)!


### Perbaikan bug

- Mac Mouse Fix sekarang bekerja dengan baik dengan **Fast User Switching**!
  - Fast User Switching adalah ketika Anda masuk ke akun macOS kedua tanpa keluar dari akun pertama.
  - Sebelum pembaruan ini, fungsi scroll berhenti bekerja setelah perpindahan pengguna cepat. Sekarang semuanya seharusnya bekerja dengan benar.
- Memperbaiki bug kecil di mana tata letak tab Buttons terlalu lebar setelah menjalankan Mac Mouse Fix untuk pertama kali.
- Membuat bidang '+' bekerja lebih andal saat menambahkan beberapa Action secara berurutan cepat.
- Memperbaiki crash yang jarang terjadi yang dilaporkan oleh @V-Coba di Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Peningkatan lainnya

- **Scrolling terasa lebih responsif** saat menggunakan pengaturan 'Smoothness: Regular'.
  - Kecepatan animasi sekarang menjadi lebih cepat saat Anda menggerakkan scroll wheel lebih cepat. Dengan begitu, terasa lebih responsif saat Anda scroll cepat sambil tetap terasa halus saat Anda scroll pelan.
  
- Membuat **akselerasi kecepatan scroll** lebih stabil dan dapat diprediksi.
- Menerapkan mekanisme untuk **menyimpan pengaturan Anda** saat memperbarui ke versi Mac Mouse Fix yang baru.
  - Sebelumnya, Mac Mouse Fix akan mengatur ulang semua pengaturan Anda setelah memperbarui ke versi baru, jika struktur pengaturan berubah. Sekarang, Mac Mouse Fix akan mencoba meningkatkan struktur pengaturan Anda dan mempertahankan preferensi Anda.
  - Sejauh ini, ini hanya berfungsi saat memperbarui dari 3.0.0 ke 3.0.1. Jika Anda memperbarui dari versi yang lebih lama dari 3.0.0, atau jika Anda _menurunkan versi_ dari 3.0.1 _ke_ versi sebelumnya, pengaturan Anda masih akan diatur ulang.
- Tata letak tab Buttons sekarang lebih baik menyesuaikan lebarnya dengan berbagai bahasa.
- Peningkatan pada [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) dan dokumen lainnya.
- Peningkatan sistem lokalisasi. File terjemahan sekarang secara otomatis dibersihkan dan dianalisis untuk masalah potensial. Ada [Panduan Lokalisasi](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) baru yang menampilkan masalah yang terdeteksi secara otomatis beserta informasi berguna lainnya dan instruksi untuk orang yang ingin membantu menerjemahkan Mac Mouse Fix. Menghapus ketergantungan pada alat [BartyCrouch](https://github.com/FlineDev/BartyCrouch) yang sebelumnya digunakan untuk mendapatkan beberapa fungsi ini.
- Meningkatkan beberapa string UI dalam bahasa Inggris dan Jerman.
- Banyak pembersihan dan peningkatan di balik layar.

---

Lihat juga catatan rilis untuk [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - pembaruan terbesar untuk Mac Mouse Fix sejauh ini!