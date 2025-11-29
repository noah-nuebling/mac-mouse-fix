Mac Mouse Fix **3.0.8** memperbaiki masalah UI dan lainnya.

### **Masalah UI**

- Menonaktifkan desain baru pada macOS 26 Tahoe. Sekarang aplikasi akan terlihat dan berfungsi seperti pada macOS 15 Sequoia.
    - Saya melakukan ini karena beberapa elemen UI yang didesain ulang oleh Apple masih memiliki masalah. Misalnya, tombol '-' pada tab 'Buttons' tidak selalu bisa diklik.
    - UI mungkin terlihat sedikit ketinggalan zaman pada macOS 26 Tahoe sekarang. Tapi seharusnya sepenuhnya berfungsi dan rapi seperti sebelumnya.
- Memperbaiki bug di mana notifikasi 'Free days are over' akan terjebak di sudut kanan atas layar.
    - Terima kasih kepada [Sashpuri](https://github.com/Sashpuri) dan lainnya yang telah melaporkannya!

### **Polesan UI**

- Menonaktifkan tombol traffic light hijau di jendela utama Mac Mouse Fix.
    - Tombol tersebut tidak melakukan apa-apa, karena jendela tidak dapat diubah ukurannya secara manual.
- Memperbaiki masalah di mana beberapa garis horizontal di tabel pada tab 'Buttons' terlalu gelap pada macOS 26 Tahoe.
- Memperbaiki bug di mana pesan "Primary Mouse Button can't be used" pada tab 'Buttons' terkadang terpotong pada macOS 26 Tahoe.
- Memperbaiki kesalahan ketik di antarmuka Jerman. Berkat pengguna GitHub [i-am-the-slime](https://github.com/i-am-the-slime). Terima kasih!
- Mengatasi masalah di mana jendela MMF terkadang berkedip sebentar dengan ukuran yang salah saat membuka jendela pada macOS 26 Tahoe.

### **Perubahan Lainnya**

- Meningkatkan perilaku saat mencoba mengaktifkan Mac Mouse Fix ketika beberapa instance Mac Mouse Fix berjalan di komputer.
    - Mac Mouse Fix sekarang akan mencoba menonaktifkan instance Mac Mouse Fix lainnya dengan lebih tekun.
    - Ini mungkin memperbaiki kasus-kasus khusus di mana Mac Mouse Fix tidak dapat diaktifkan.
- Perubahan dan pembersihan di balik layar.

---

Lihat juga apa yang baru di versi sebelumnya [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).