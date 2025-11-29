Mac Mouse Fix **3.0.6** membuat fitur 'Kembali' dan 'Maju' kompatibel dengan lebih banyak aplikasi.
Versi ini juga memperbaiki beberapa bug dan masalah.

### Peningkatan Fitur 'Kembali' dan 'Maju'

Pemetaan tombol mouse 'Kembali' dan 'Maju' sekarang **berfungsi di lebih banyak aplikasi**, termasuk:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed, dan editor kode lainnya
- Banyak aplikasi bawaan Apple seperti Preview, Notes, System Settings, App Store, dan Music
- Adobe Acrobat
- Zotero
- Dan masih banyak lagi!

Implementasinya terinspirasi dari fitur 'Universal Back and Forward' yang hebat di [LinearMouse](https://github.com/linearmouse/linearmouse). Seharusnya mendukung semua aplikasi yang didukung LinearMouse. \
Selain itu, fitur ini mendukung beberapa aplikasi yang biasanya memerlukan pintasan keyboard untuk kembali dan maju, seperti System Settings, App Store, Apple Notes, dan Adobe Acrobat. Mac Mouse Fix sekarang akan mendeteksi aplikasi tersebut dan mensimulasikan pintasan keyboard yang sesuai.

Setiap aplikasi yang pernah [diminta dalam GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) seharusnya sudah didukung sekarang! (Terima kasih atas masukannya!) \
Jika kamu menemukan aplikasi yang belum berfungsi, beri tahu saya melalui [permintaan fitur](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Mengatasi Bug 'Scroll Berhenti Bekerja Secara Berkala'

Beberapa pengguna mengalami [masalah](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) di mana **smooth scrolling berhenti bekerja** secara acak.

Meskipun saya tidak pernah bisa mereproduksi masalah ini, saya telah menerapkan perbaikan potensial:

Aplikasi sekarang akan mencoba beberapa kali, ketika pengaturan sinkronisasi layar gagal. \
Jika masih tidak berhasil setelah mencoba ulang, aplikasi akan:

- Memulai ulang proses latar belakang 'Mac Mouse Fix Helper', yang mungkin menyelesaikan masalah
- Menghasilkan laporan crash, yang dapat membantu mendiagnosis bug

Saya harap masalahnya sudah teratasi sekarang! Jika belum, beri tahu saya melalui [laporan bug](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) atau via [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Peningkatan Perilaku Scroll Wheel yang Berputar Bebas

Mac Mouse Fix **tidak akan lagi mempercepat scrolling** untuk kamu, ketika kamu membiarkan scroll wheel berputar bebas pada mouse MX Master. (Atau mouse lain dengan scroll wheel yang berputar bebas.)

Meskipun fitur 'percepatan scroll' ini berguna pada scroll wheel biasa, pada scroll wheel yang berputar bebas fitur ini dapat membuat kontrol menjadi lebih sulit.

**Catatan:** Mac Mouse Fix saat ini belum sepenuhnya kompatibel dengan sebagian besar mouse Logitech, termasuk MX Master. Saya berencana menambahkan dukungan penuh, tetapi mungkin akan memakan waktu cukup lama. Sementara itu, driver pihak ketiga terbaik dengan dukungan Logitech yang saya tahu adalah [SteerMouse](https://plentycom.jp/en/steermouse/).





### Perbaikan Bug

- Memperbaiki masalah di mana Mac Mouse Fix terkadang mengaktifkan kembali pintasan keyboard yang sebelumnya dinonaktifkan di System Settings  
- Memperbaiki crash saat mengklik 'Activate License' 
- Memperbaiki crash saat mengklik 'Cancel' tepat setelah mengklik 'Activate License' (Terima kasih atas laporannya, Ali!)
- Memperbaiki crash saat mencoba menggunakan Mac Mouse Fix ketika tidak ada layar yang terhubung ke Mac kamu 
- Memperbaiki kebocoran memori dan beberapa masalah internal lainnya saat berpindah antar tab di aplikasi 

### Peningkatan Visual

- Memperbaiki masalah di mana tab About terkadang terlalu tinggi, yang muncul di [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Teks pada notifikasi 'Free days are over' tidak lagi terpotong dalam bahasa Mandarin
- Memperbaiki glitch visual pada bayangan field '+' setelah merekam input
- Memperbaiki glitch langka di mana teks placeholder pada layar 'Enter Your License Key' muncul tidak di tengah
- Memperbaiki masalah di mana beberapa simbol yang ditampilkan di aplikasi memiliki warna yang salah setelah berpindah antara mode gelap/terang

### Peningkatan Lainnya

- Membuat beberapa animasi, seperti animasi perpindahan tab, sedikit lebih efisien  
- Menonaktifkan pelengkapan teks Touch Bar pada layar 'Enter Your License Key' 
- Berbagai peningkatan internal yang lebih kecil

*Diedit dengan bantuan luar biasa dari Claude.*

---

Lihat juga rilis sebelumnya [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).