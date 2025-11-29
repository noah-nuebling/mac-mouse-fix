Mac Mouse Fix **3.0.5** memperbaiki beberapa bug, meningkatkan performa, dan menambahkan sedikit polesan pada aplikasi. \
Aplikasi ini juga kompatibel dengan macOS 26 Tahoe.

### Peningkatan Simulasi Scrolling Trackpad

- Sistem scrolling kini dapat mensimulasikan ketukan dua jari pada trackpad untuk membuat aplikasi berhenti scrolling.
    - Ini memperbaiki masalah saat menjalankan aplikasi iPhone atau iPad, di mana scrolling sering terus berjalan setelah pengguna memilih untuk berhenti.
- Memperbaiki simulasi yang tidak konsisten saat mengangkat jari dari trackpad.
    - Ini mungkin telah menyebabkan perilaku yang kurang optimal dalam beberapa situasi.



### Kompatibilitas macOS 26 Tahoe

Saat menjalankan macOS 26 Tahoe Beta, aplikasi kini dapat digunakan, dan sebagian besar UI berfungsi dengan benar.



### Peningkatan Performa

Meningkatkan performa gesture Klik dan Seret untuk "Scroll & Navigate". \
Dalam pengujian saya, penggunaan CPU telah berkurang sekitar ~50%!

**Latar Belakang**

Selama gesture "Scroll & Navigate", Mac Mouse Fix menggambar kursor mouse palsu di jendela transparan, sambil mengunci kursor mouse asli di tempatnya. Ini memastikan bahwa kamu dapat terus scrolling elemen UI yang kamu mulai scrolling, tidak peduli seberapa jauh kamu menggerakkan mouse.

Peningkatan performa dicapai dengan mematikan penanganan event macOS default pada jendela transparan ini, yang memang tidak digunakan.





### Perbaikan Bug

- Kini mengabaikan event scroll dari tablet gambar Wacom.
    - Sebelumnya, Mac Mouse Fix menyebabkan scrolling yang tidak menentu pada tablet Wacom, seperti yang dilaporkan oleh @frenchie1980 di GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Terima kasih!)
    
- Memperbaiki bug di mana kode Swift Concurrency, yang diperkenalkan sebagai bagian dari sistem lisensi baru di Mac Mouse Fix 3.0.4, tidak berjalan pada thread yang benar.
    - Ini menyebabkan crash pada macOS Tahoe, dan kemungkinan juga menyebabkan bug sporadis lainnya terkait lisensi.
- Meningkatkan ketahanan kode yang mendekode lisensi offline.
    - Ini mengatasi masalah di API Apple yang menyebabkan validasi lisensi offline selalu gagal di Mac Mini Intel saya. Saya berasumsi bahwa ini terjadi pada semua Mac Intel, dan bahwa ini adalah alasan mengapa bug "Free days are over" (yang sudah ditangani di 3.0.4) masih terjadi untuk beberapa orang, seperti yang dilaporkan oleh @toni20k5267 di GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Terima kasih!)
        - Jika kamu mengalami bug "Free days are over", saya minta maaf! Kamu bisa mendapatkan refund [di sini](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Peningkatan UX

- Menonaktifkan dialog yang memberikan solusi langkah demi langkah untuk bug macOS yang mencegah pengguna mengaktifkan Mac Mouse Fix.
    - Masalah ini hanya terjadi pada macOS 13 Ventura dan 14 Sonoma. Sekarang, dialog ini hanya muncul pada versi macOS yang relevan. 
    - Dialog juga sedikit lebih sulit dipicu – sebelumnya, dialog kadang muncul dalam situasi di mana mereka tidak terlalu membantu.
    
- Menambahkan link "Activate License" langsung pada notifikasi "Free days are over". 
    - Ini membuat aktivasi lisensi Mac Mouse Fix menjadi lebih mudah!

### Peningkatan Visual

- Sedikit meningkatkan tampilan jendela "Software Update". Sekarang lebih cocok dengan macOS 26 Tahoe. 
    - Ini dilakukan dengan menyesuaikan tampilan default framework "Sparkle 1.27.3" yang digunakan Mac Mouse Fix untuk menangani update.
- Memperbaiki masalah di mana teks di bagian bawah tab About kadang terpotong dalam bahasa Mandarin, dengan membuat jendela sedikit lebih lebar.
- Memperbaiki teks di bagian bawah tab About yang sedikit tidak berada di tengah.
- Memperbaiki bug yang menyebabkan ruang di bawah opsi "Keyboard Shortcut..." pada tab Buttons terlalu kecil. 

### Perubahan Internal

- Menghapus ketergantungan pada framework "SnapKit".
    - Ini sedikit mengurangi ukuran aplikasi dari 19,8 menjadi 19,5 MB.
- Berbagai peningkatan kecil lainnya dalam codebase.

*Diedit dengan bantuan luar biasa dari Claude.*

---

Lihat juga rilis sebelumnya [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).