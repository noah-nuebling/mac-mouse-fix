Mac Mouse Fix **3.0.7** memperbaiki beberapa bug penting.

### Perbaikan Bug

- Aplikasi berfungsi kembali di **versi macOS lama** (macOS 10.15 Catalina dan macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 tidak dapat diaktifkan di versi macOS tersebut karena fitur 'Back' dan 'Forward' yang ditingkatkan yang diperkenalkan di Mac Mouse Fix 3.0.6 mencoba menggunakan API sistem macOS yang tidak tersedia.
- Memperbaiki masalah dengan fitur **'Back' dan 'Forward'**
    - Fitur 'Back' dan 'Forward' yang ditingkatkan yang diperkenalkan di Mac Mouse Fix 3.0.6 sekarang akan selalu menggunakan 'main thread' untuk menanyakan macOS tentang penekanan tombol mana yang harus disimulasikan untuk kembali dan maju di aplikasi yang kamu gunakan. \
    Ini dapat mencegah crash dan perilaku yang tidak dapat diandalkan dalam beberapa situasi.
- Mencoba memperbaiki bug di mana **pengaturan direset secara acak**  (Lihat [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22) ini)
    - Saya menulis ulang kode yang memuat file konfigurasi untuk Mac Mouse Fix agar lebih kuat. Ketika terjadi error file-system macOS yang jarang terjadi, kode lama terkadang bisa salah mengira bahwa file konfigurasi rusak dan meresetnya ke default.
- Mengurangi kemungkinan bug di mana **scrolling berhenti berfungsi**     
     - Bug ini tidak dapat diperbaiki sepenuhnya tanpa perubahan yang lebih mendalam, yang kemungkinan akan menyebabkan masalah lain. \
      Namun, untuk sementara waktu, saya mengurangi jendela waktu di mana 'deadlock' dapat terjadi di sistem scrolling, yang setidaknya akan menurunkan kemungkinan menemui bug ini. Ini juga membuat scrolling sedikit lebih efisien. 
    - Bug ini memiliki gejala yang mirip – tetapi saya pikir alasan mendasar yang berbeda – dengan bug 'Scroll Stops Working Intermittently' yang telah diperbaiki di rilis terakhir 3.0.6.
    - (Terima kasih kepada Joonas untuk diagnostiknya!) 

Terima kasih semua yang telah melaporkan bug! 

---

Lihat juga rilis sebelumnya [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).