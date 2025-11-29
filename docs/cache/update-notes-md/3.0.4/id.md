Mac Mouse Fix **3.0.4** meningkatkan privasi, efisiensi, dan keandalan.\
Versi ini memperkenalkan sistem lisensi offline baru, dan memperbaiki beberapa bug penting.

### Peningkatan Privasi & Efisiensi

3.0.4 memperkenalkan sistem validasi lisensi offline baru yang meminimalkan koneksi internet sebanyak mungkin.\
Ini meningkatkan privasi dan menghemat sumber daya sistem komputer kamu.\
Saat berlisensi, aplikasi sekarang beroperasi 100% offline!

<details>
<summary><b>Klik di sini untuk detail lebih lanjut</b></summary>
Versi sebelumnya memvalidasi lisensi secara online di setiap peluncuran, yang berpotensi memungkinkan log koneksi disimpan oleh server pihak ketiga (GitHub dan Gumroad). Sistem baru menghilangkan koneksi yang tidak perlu – setelah aktivasi lisensi awal, sistem hanya terhubung ke internet jika data lisensi lokal rusak.
<br><br>
Meskipun tidak ada perilaku pengguna yang pernah dicatat oleh saya secara pribadi, sistem sebelumnya secara teoritis memungkinkan server pihak ketiga untuk mencatat alamat IP dan waktu koneksi. Gumroad juga dapat mencatat kunci lisensi kamu dan berpotensi menghubungkannya dengan info pribadi apa pun yang mereka catat tentang kamu saat kamu membeli Mac Mouse Fix.
<br><br>
Saya tidak mempertimbangkan masalah privasi yang halus ini ketika saya membangun sistem lisensi asli, tetapi sekarang, Mac Mouse Fix seprivat dan sebebas internet mungkin!
<br><br>
Lihat juga <a href=https://gumroad.com/privacy>kebijakan privasi Gumroad</a> dan <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>komentar GitHub</a> saya ini.

</details>

### Perbaikan Bug

- Memperbaiki bug di mana macOS terkadang macet saat menggunakan 'Click and Drag' untuk 'Spaces & Mission Control'.
- Memperbaiki bug di mana pintasan keyboard di System Settings terkadang terhapus saat menggunakan aksi 'Click' Mac Mouse Fix seperti 'Mission Control'.
- Memperbaiki [bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) di mana aplikasi terkadang berhenti bekerja dan menampilkan notifikasi bahwa 'Free days are over' kepada pengguna yang sudah membeli aplikasi.
    - Jika kamu mengalami bug ini, saya dengan tulus meminta maaf atas ketidaknyamanannya. Kamu dapat mengajukan [pengembalian dana di sini](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Meningkatkan cara aplikasi mengambil jendela utamanya, yang mungkin telah memperbaiki bug di mana layar 'Activate License' terkadang gagal muncul.

### Peningkatan Kegunaan

- Membuat tidak mungkin untuk memasukkan spasi dan baris baru di kolom teks pada layar 'Activate License'.
    - Ini adalah titik kebingungan yang umum, karena sangat mudah untuk secara tidak sengaja memilih baris baru yang tersembunyi saat menyalin kunci lisensi kamu dari email Gumroad.
- Catatan pembaruan ini diterjemahkan secara otomatis untuk pengguna non-Inggris (Didukung oleh Claude). Saya harap ini membantu! Jika kamu menemukan masalah apa pun, beri tahu saya. Ini adalah gambaran pertama dari sistem terjemahan baru yang telah saya kembangkan selama setahun terakhir.

### Penghentian Dukungan (Tidak Resmi) untuk macOS 10.14 Mojave

Mac Mouse Fix 3 secara resmi mendukung macOS 11 Big Sur dan yang lebih baru. Namun, untuk pengguna yang bersedia menerima beberapa gangguan dan masalah grafis, Mac Mouse Fix 3.0.3 dan versi sebelumnya masih dapat digunakan di macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 menghentikan dukungan tersebut dan **sekarang memerlukan macOS 10.15 Catalina**. \
Saya meminta maaf atas ketidaknyamanan yang ditimbulkan oleh hal ini. Perubahan ini memungkinkan saya untuk mengimplementasikan sistem lisensi yang ditingkatkan menggunakan fitur Swift modern. Pengguna Mojave dapat terus menggunakan Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) atau [versi terbaru Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Saya harap itu solusi yang baik untuk semua orang.

### Peningkatan Internal

- Mengimplementasikan sistem 'MFDataClass' baru yang memungkinkan pemodelan data yang lebih kuat sambil menjaga file konfigurasi Mac Mouse Fix tetap dapat dibaca dan diedit oleh manusia.
- Membangun dukungan untuk menambahkan platform pembayaran selain Gumroad. Jadi di masa depan, mungkin ada checkout yang dilokalkan, dan aplikasi dapat dijual ke berbagai negara.
- Meningkatkan logging yang memungkinkan saya membuat "Debug Builds" yang lebih efektif untuk pengguna yang mengalami bug yang sulit direproduksi.
- Banyak peningkatan kecil dan pekerjaan pembersihan lainnya.

*Diedit dengan bantuan luar biasa dari Claude.*

---

Lihat juga rilis sebelumnya [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).