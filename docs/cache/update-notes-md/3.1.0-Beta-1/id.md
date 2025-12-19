Mac Mouse Fix **3.1.0 Beta 1** menghadirkan sistem terjemahan baru yang hebat, yang telah dikerjakan untuk beberapa waktu.\
Ada juga beberapa peningkatan UI.

### Sistem lokalisasi baru!

- Sekarang sangat mudah untuk berkontribusi terjemahan berkualitas tinggi ke Mac Mouse Fix, tanpa memerlukan latar belakang teknis sama sekali.
- Tersedia banyak tangkapan layar beranotasi dan komentar, serta fungsi pencarian yang bagus, sehingga penerjemah dapat dengan mudah memahami persis bagaimana terjemahan mereka muncul di aplikasi.
    - Saya pikir tangkapan layar dan UI terjemahan (aplikasi `Xcloc Editor`) adalah yang terbaik di pasaran, dan saya berharap ini akan membantu Anda memberikan terjemahan yang hebat!
- Hampir semua bagian proyek sekarang dapat diterjemahkan, termasuk 'Panduan Tombol yang Ditangkap', GitHub Readme, Website, dan lainnya.
    - Semua bagian proyek ini dapat diterjemahkan dari satu tempat terpusat dengan referensi silang yang mudah menggunakan aplikasi `Xcloc Editor`, sehingga mudah bagi penerjemah untuk menjaga semuanya tetap konsisten.
- Sistem ini dirancang agar sangat mudah dipelihara, jadi seiring Mac Mouse Fix berkembang dan layar atau teks baru ditambahkan, semuanya akan diperbarui secara otomatis.
- Penafian: Saya sering menggunakan kata 'mudah'. Alur kerjanya mudah, tetapi memikirkan terjemahan yang hebat tentu saja masih merupakan pekerjaan yang keras dan patut dihormati! Hanya saja sekarang ada lebih sedikit hambatan.




Terjemahan baru telah dengan murah hati disediakan oleh orang-orang berikut:

- **Eduardo Rodrigues**: 🇧🇷 Terjemahan Portugis Brasil
- [@DimitriDR](https://github.com/DimitriDR): 🇫🇷 Terjemahan Prancis
- [@hasanbeder](https://github.com/hasanbeder) dan [@erentomurcuk](https://github.com/erentomurcuk): 🇹🇷 Terjemahan Turki
- [Petr Pavlík](http://www.petrpavlik.com): 🇨🇿 Terjemahan Ceko
- [@Dro9an](https://github.com/Dro9an) dan [@jihao](https://github.com/jihao): 🇨🇳 Terjemahan Tiongkok untuk [website](macmousefix.com)

Terima kasih atas kerja kalian!

Namun, **semua bahasa masih memerlukan pekerjaan**, karena banyak hal baru telah dibuat dapat diterjemahkan.

Oleh karena itu:

> [!TIP]
> Lihat [Panduan Terjemahan](https://redirect.macmousefix.com/?target=mmf-localization-contribution) baru jika Anda ingin membantu menghadirkan terjemahan hebat kepada pengguna Mac Mouse Fix di seluruh dunia! 🌎

### Perubahan lainnya

Saat menggunakan Mac Mouse Fix dalam bahasa Inggris, tidak banyak yang berubah, tetapi beberapa hal telah diperbarui di UI, dan banyak yang berubah di balik layar, untuk membantu membuat terjemahan lebih baik:

- Tampilan yang lebih halus untuk notifikasi popup kecil.
- Tooltip dan pesan kesalahan yang lebih jelas di berbagai tempat.
- Tombol escape sekarang dapat digunakan di mana saja untuk menutup notifikasi, sheet, dan popup.
- Tautan 'Bantu Menerjemahkan' telah ditambahkan ke Tab Tentang.
- Lebar tampilan dan popup telah disesuaikan agar terlihat bagus dalam berbagai bahasa.
- Tata letak teks yang lebih baik untuk bahasa Tiongkok dan Korea, yang memiliki masalah pembungkusan teks di beberapa notifikasi popup kecil.
- Mengganti pustaka parsing Markdown untuk memperbaiki beberapa bug pemformatan dalam bahasa Tionghua dan Korea.
- Banyak lagi perubahan dan peningkatan di balik layar.



---

Anda dapat menemukan rilis Mac Mouse Fix sebelumnya di sini: [3.0.8](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.8)

---

Pembaruan:
(Saya memperbarui terjemahan tanpa membuat GitHub Release baru setiap kali.)

1. Pembaruan:
    - Nomor build aset MacMouseFixApp.zip: 24814
    - Tanggal: [8 Des 2025]
    - Perubahan: Menambahkan terjemahan Rusia oleh Vyacheslav

2. Pembaruan:
    - Nomor build aset MacMouseFixApp.zip: 24815
    - Tanggal: [15 Des 2025]
    - Perubahan: Memperbarui terjemahan Ceko oleh Petr

3. Pembaruan:
    - Nomor build aset MacMouseFixApp.zip: 24822
    - Tanggal: [15 Des 2025]
    - Perubahan:
        - Menambahkan terjemahan Turki oleh Eren.
        - Membuat margin horizontal pada tab Scrolling sedikit lebih sempit agar bekerja lebih baik dengan beberapa string UI Turki yang lebih lebar.
        - Memperbaiki masalah rendering Markdown di mana poin-poin daftar akan memiliki garis bawah jika hal pertama setelah daftar adalah tautan. Ini memengaruhi bahasa Turki di beberapa tempat.