Mac Mouse Fix **2.2.4** sekarang telah dinotarisasi! Versi ini juga mencakup beberapa perbaikan bug dan peningkatan lainnya.

### **Notarisasi**

Mac Mouse Fix 2.2.4 kini telah 'dinotarisasi' oleh Apple. Artinya tidak akan ada lagi pesan tentang Mac Mouse Fix yang berpotensi sebagai 'Perangkat Lunak Berbahaya' saat membuka aplikasi untuk pertama kali.

#### Latar Belakang

Notarisasi aplikasi membutuhkan biaya $100 per tahun. Saya selalu menentang hal ini, karena terasa tidak ramah terhadap perangkat lunak gratis dan open source seperti Mac Mouse Fix, dan juga terasa seperti langkah berbahaya menuju Apple yang mengontrol dan mengunci Mac seperti yang mereka lakukan pada iPhone atau iPad. Namun ketiadaan notarisasi menyebabkan berbagai masalah, termasuk [kesulitan membuka aplikasi](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) dan bahkan [beberapa situasi](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) di mana tidak ada yang bisa menggunakan aplikasi sampai saya merilis versi baru.

Untuk Mac Mouse Fix 3, saya akhirnya merasa tepat untuk membayar $100 per tahun untuk notarisasi aplikasi, karena Mac Mouse Fix 3 sudah dimonetisasi. ([Pelajari Lebih Lanjut](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Sekarang, Mac Mouse Fix 2 juga mendapatkan notarisasi, yang seharusnya menghasilkan pengalaman pengguna yang lebih mudah dan stabil.

### **Perbaikan Bug**

- Memperbaiki masalah di mana kursor akan menghilang dan kemudian muncul kembali di lokasi berbeda saat menggunakan Aksi 'Klik dan Seret' selama perekaman layar atau saat menggunakan perangkat lunak [DisplayLink](https://www.synaptics.com/products/displaylink-graphics).
- Memperbaiki masalah dengan mengaktifkan Mac Mouse Fix di macOS 10.14 Mojave dan kemungkinan versi macOS yang lebih lama juga.
- Meningkatkan manajemen memori, berpotensi memperbaiki crash pada aplikasi 'Mac Mouse Fix Helper', yang terjadi saat melepaskan mouse dari komputer Anda. Lihat Diskusi [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).

### **Peningkatan Lainnya**

- Jendela yang ditampilkan aplikasi untuk memberi tahu Anda bahwa versi baru Mac Mouse Fix tersedia sekarang mendukung JavaScript. Ini memungkinkan catatan pembaruan menjadi lebih cantik dan lebih mudah dibaca. Misalnya, catatan pembaruan sekarang dapat menampilkan [Markdown Alerts](https://github.com/orgs/community/discussions/16925) dan lainnya.
- Menghapus tautan ke halaman https://macmousefix.com/about/ dari layar "Berikan Akses Aksesibilitas ke Mac Mouse Fix Helper". Ini karena halaman About tidak lagi ada dan untuk sementara digantikan oleh [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix).
- Rilis ini sekarang menyertakan file dSYM yang dapat digunakan oleh siapa saja untuk mendekode laporan crash Mac Mouse Fix 2.2.4.
- Beberapa pembersihan dan peningkatan di balik layar.

---

Lihat juga rilis sebelumnya [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).