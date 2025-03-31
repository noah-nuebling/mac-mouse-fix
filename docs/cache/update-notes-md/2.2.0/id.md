Coba lihat juga **fitur keren** yang diperkenalkan di [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** memiliki berbagai peningkatan kegunaan dan perbaikan bug!

### Pemetaan ulang ke tombol fungsi khusus Apple kini lebih baik

Pembaruan terakhir, 2.1.0, memperkenalkan fitur baru yang keren yang memungkinkan Anda memetakan ulang tombol mouse ke tombol apa pun di keyboard - bahkan tombol fungsi yang hanya ada di keyboard Apple. 2.2.0 memiliki peningkatan dan penyempurnaan lebih lanjut untuk fitur tersebut:

- Anda sekarang dapat menahan Option (⌥) untuk memetakan ulang ke tombol yang hanya ada di keyboard Apple - bahkan jika Anda tidak memiliki keyboard Apple.
- Simbol tombol fungsi memiliki tampilan yang lebih baik, membuatnya lebih sesuai dengan teks lainnya.
- Kemampuan untuk memetakan ulang ke Caps Lock telah dinonaktifkan. Fitur ini tidak berfungsi seperti yang diharapkan.

### Menambah / menghapus Tindakan lebih mudah

Beberapa pengguna kesulitan mengetahui bahwa Anda dapat menambah dan menghapus Tindakan dari Tabel Tindakan. Untuk membuatnya lebih mudah dipahami, 2.2.0 memiliki perubahan dan fitur baru berikut:

- Anda sekarang dapat menghapus Tindakan dengan mengklik kanan.
  - Ini akan memudahkan menemukan opsi untuk menghapus Tindakan.
  - Menu klik kanan menampilkan simbol tombol '-'. Ini akan membantu menarik perhatian ke _tombol_ '-', yang kemudian akan menarik perhatian ke tombol '+'. Hal ini diharapkan membuat opsi untuk **menambah** Tindakan lebih mudah ditemukan.
- Anda sekarang dapat menambahkan Tindakan ke Tabel Tindakan dengan mengklik kanan baris kosong.
- Tombol '-' sekarang hanya aktif ketika Tindakan dipilih. Ini akan memperjelas bahwa tombol '-' menghapus Tindakan yang dipilih.
- Tinggi jendela default telah ditingkatkan sehingga ada baris kosong yang terlihat yang dapat diklik kanan untuk menambahkan Tindakan.
- Tombol '+' dan '-' sekarang memiliki tooltip.

### Peningkatan Klik dan Seret

Ambang batas untuk mengaktifkan Klik dan Seret telah ditingkatkan dari 5 piksel menjadi 7 piksel. Ini membuat lebih sulit untuk tidak sengaja mengaktifkan Klik dan Seret, sambil tetap memungkinkan pengguna beralih Spaces dll. dengan menggunakan gerakan kecil yang nyaman.

### Perubahan UI lainnya

- Tampilan Tabel Tindakan telah ditingkatkan.
- Berbagai peningkatan UI lainnya.

### Perbaikan bug

- Memperbaiki masalah di mana UI tidak dinonaktifkan saat memulai MMF ketika dinonaktifkan.
- Menghapus opsi tersembunyi "Button 3 Click and Drag".
  - Saat memilihnya, aplikasi akan crash. Saya membuat opsi ini untuk membuat Mac Mouse Fix lebih kompatibel dengan Blender. Tapi dalam bentuknya saat ini, tidak terlalu berguna untuk pengguna Blender karena Anda tidak dapat menggabungkannya dengan modifier keyboard. Saya berencana untuk meningkatkan kompatibilitas Blender dalam rilis mendatang.