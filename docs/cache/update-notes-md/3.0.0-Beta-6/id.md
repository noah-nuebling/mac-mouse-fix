Cek juga **perubahan keren** yang diperkenalkan di [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** membawa optimisasi mendalam dan penyempurnaan, pengerjaan ulang pengaturan scroll, terjemahan bahasa Mandarin, dan banyak lagi!

Berikut semua yang baru:

## 1. Optimisasi Mendalam

Untuk Beta ini, saya telah bekerja keras untuk mendapatkan performa maksimal dari Mac Mouse Fix. Dan sekarang saya senang mengumumkan bahwa, ketika Anda mengklik tombol mouse di Beta 6, itu **2x** lebih cepat dibandingkan beta sebelumnya! Dan scrolling bahkan **4x** lebih cepat!

Dengan Beta 6, MMF juga akan secara cerdas mematikan bagian-bagian tertentu untuk menghemat CPU dan baterai semaksimal mungkin.

Misalnya, ketika Anda sedang menggunakan mouse dengan 3 tombol tetapi Anda hanya mengatur tindakan untuk tombol yang tidak ada di mouse Anda seperti tombol 4 dan 5, Mac Mouse Fix akan berhenti mendengarkan input tombol dari mouse Anda sepenuhnya. Artinya penggunaan CPU 0% ketika Anda mengklik tombol pada mouse! Atau ketika pengaturan scroll di MMF cocok dengan sistem, Mac Mouse Fix akan berhenti mendengarkan input dari roda scroll sepenuhnya. Artinya penggunaan CPU 0% ketika Anda scroll! Tetapi jika Anda mengatur fitur Command (⌘)-Scroll untuk Zoom, Mac Mouse Fix akan mulai mendengarkan input roda scroll Anda - tetapi hanya saat Anda menahan tombol Command (⌘). Dan seterusnya.
Jadi benar-benar cerdas dan hanya akan menggunakan CPU ketika diperlukan!

Ini berarti, MMF sekarang bukan hanya driver mouse yang paling powerful, mudah digunakan, dan halus untuk Mac, tapi juga salah satu, jika bukan yang paling, teroptimasi dan efisien!

## 2. Ukuran Aplikasi Berkurang

Dengan 16 MB, Beta 6 sekitar 2x lebih kecil dari Beta 5!

Ini adalah efek samping dari penghentian dukungan untuk versi macOS yang lebih lama.

## 3. Penghentian Dukungan untuk Versi macOS Lama

Saya berusaha keras untuk membuat MMF 3 berjalan dengan baik pada versi macOS sebelum macOS 11 Big Sur. Tapi jumlah pekerjaan untuk membuatnya terasa halus ternyata sangat berat, jadi saya harus menyerah.

Ke depannya, versi yang secara resmi didukung adalah macOS 11 Big Sur dan yang lebih baru.

Aplikasi masih akan terbuka di versi yang lebih lama tetapi akan ada masalah visual dan mungkin masalah lainnya. Aplikasi tidak akan terbuka lagi pada versi macOS sebelum 10.14.4. Ini yang memungkinkan kita untuk mengecilkan ukuran aplikasi hingga 2x karena 10.14.4 adalah versi macOS paling awal yang dilengkapi dengan pustaka Swift modern (Lihat "Swift ABI Stability"), yang berarti pustaka Swift tersebut tidak perlu lagi disertakan dalam aplikasi.

## 4. Peningkatan Scroll

Beta 6 memiliki banyak peningkatan pada konfigurasi dan UI dari sistem scrolling baru yang diperkenalkan di MMF 3.

### UI

- Sangat menyederhanakan dan mempersingkat teks UI pada tab Scroll. Sebagian besar kata "Scroll" telah dihapus karena sudah tersirat dari konteks.
- Mengerjakan ulang pengaturan kelancaran scroll agar lebih jelas dan memungkinkan beberapa opsi tambahan. Sekarang Anda dapat memilih antara "Kelancaran" "Mati", "Regular", atau "Tinggi", Menggantikan toggle lama "dengan Inersia". Saya pikir ini jauh lebih jelas dan membuat ruang di UI untuk opsi baru "Simulasi Trackpad".
- Mematikan opsi "Simulasi Trackpad" baru menonaktifkan efek karet saat scrolling, juga mencegah scrolling antar halaman di Safari dan aplikasi lainnya, dan lainnya. Banyak orang terganggu oleh ini, terutama mereka yang memiliki roda scroll bebas seperti yang ditemukan pada beberapa Mouse Logitech seperti MX Master, tetapi yang lain menikmatinya, jadi saya memutuskan untuk menjadikannya sebuah opsi. Saya harap presentasi fitur ini jelas. Jika Anda memiliki saran, beri tahu saya.
- Mengubah opsi "Arah Scroll Natural" menjadi "Balik Arah Scroll". Ini berarti pengaturan sekarang membalik arah scroll sistem dan tidak lagi independen dari arah scroll sistem. Meskipun ini bisa dibilang pengalaman pengguna yang sedikit lebih buruk, cara baru ini memungkinkan kita untuk mengimplementasikan beberapa optimisasi dan membuat lebih transparan bagi pengguna bagaimana cara mematikan Mac Mouse Fix sepenuhnya untuk scrolling.
- Meningkatkan cara pengaturan scroll berinteraksi dengan scrolling yang dimodifikasi dalam banyak kasus. Misalnya, opsi "Presisi" tidak akan lagi berlaku untuk "Klik dan Scroll" untuk tindakan "Desktop & Launchpad" karena ini menjadi penghambat alih-alih membantu.
- Meningkatkan kecepatan scroll saat menggunakan "Klik dan Scroll" untuk "Desktop & Launchpad" atau "Perbesar atau Perkecil" dan fitur lainnya.
- Menghapus tautan yang tidak berfungsi ke pengaturan kecepatan scroll sistem pada tab scroll yang ada pada versi macOS sebelum macOS 13.0 Ventura. Saya tidak bisa menemukan cara untuk membuat tautan berfungsi dan ini tidak terlalu penting.

### Sensasi Scroll

- Meningkatkan kurva animasi untuk "Kelancaran Regular" (sebelumnya dapat diakses dengan mematikan "dengan Inersia"). Ini membuat hal-hal terasa lebih halus dan responsif.
- Meningkatkan sensasi semua pengaturan kecepatan scroll. Kecepatan "Sedang" dan kecepatan "Cepat" lebih cepat. Ada lebih banyak pemisahan antara kecepatan "Rendah" "Sedang" dan "Tinggi". Percepatan saat Anda menggerakkan roda scroll lebih cepat terasa lebih alami dan nyaman saat menggunakan opsi "Presisi".
- Cara kecepatan scrolling meningkat saat Anda terus scroll ke satu arah akan terasa lebih alami dan bertahap. Saya menggunakan kurva matematika baru untuk memodelkan percepatan. Peningkatan kecepatan juga akan lebih sulit dipicu secara tidak sengaja.
- Tidak lagi meningkatkan kecepatan scrolling saat Anda terus scroll ke satu arah saat menggunakan kecepatan scrolling "macOS".
- Membatasi waktu animasi scroll ke maksimum. Jika animasi scroll secara alami akan memakan waktu lebih lama, itu akan dipercepat untuk tetap di bawah waktu maksimum. Dengan demikian, scrolling ke tepi halaman dengan roda bebas-berputar tidak akan membuat konten halaman bergerak keluar layar selama itu. Ini seharusnya tidak mempengaruhi scrolling normal dengan roda yang tidak bebas-berputar.
- Meningkatkan beberapa interaksi seputar efek karet saat scrolling ke tepi halaman di Safari dan aplikasi lainnya.
- Memperbaiki masalah di mana "Klik dan Scroll" dan fitur terkait scroll lainnya tidak berfungsi dengan baik setelah upgrade dari versi preference pane Mac Mouse Fix yang sangat lama.
- Memperbaiki masalah di mana scroll satu piksel dikirim dengan penundaan saat menggunakan kecepatan scrolling "macOS" bersama dengan smooth scrolling.
- Memperbaiki bug di mana scrolling masih sangat cepat setelah melepaskan modifier Swift Scroll. Peningkatan lain seputar bagaimana kecepatan scroll dibawa dari sapuan scroll sebelumnya.
- Meningkatkan cara kecepatan scroll meningkat dengan ukuran tampilan yang lebih besar

## 5. Notarisasi

Mulai dari 3.0.0 Beta 6, Mac Mouse Fix akan "Dinotarisasi". Itu berarti tidak ada lagi pesan tentang Mac Mouse Fix yang berpotensi menjadi "Perangkat Lunak Berbahaya" saat membuka aplikasi untuk pertama kalinya.

Notarisasi aplikasi Anda membutuhkan biaya $100 per tahun. Saya selalu menentang ini, karena terasa bermusuhan terhadap perangkat lunak gratis dan open source seperti Mac Mouse Fix, dan juga terasa seperti langkah berbahaya menuju Apple mengontrol dan mengunci Mac seperti yang mereka lakukan pada iOS. Tetapi kurangnya Notarisasi menyebabkan masalah yang cukup serius, termasuk [beberapa situasi](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) di mana tidak ada yang bisa menggunakan aplikasi sampai saya merilis versi baru. Karena Mac Mouse Fix akan dimonetisasi sekarang, saya pikir akhirnya tepat untuk Notarisasi aplikasi untuk pengalaman pengguna yang lebih mudah dan lebih stabil.

## 6. Terjemahan Bahasa Mandarin

Mac Mouse Fix sekarang tersedia dalam bahasa Mandarin!
Lebih spesifik, tersedia dalam:

- Mandarin, Tradisional
- Mandarin, Sederhana
- Mandarin (Hong Kong)

Terima kasih banyak kepada @groverlynn yang telah menyediakan semua terjemahan ini serta memperbaruinya selama beta dan berkomunikasi dengan saya. Lihat pull request-nya di sini: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Hal Lainnya

Selain perubahan yang tercantum di atas, Beta 6 juga memiliki banyak peningkatan kecil.

- Menghapus beberapa opsi dari Tindakan "Klik", "Klik dan Tahan" dan "Klik dan Scroll" karena saya pikir mereka berlebihan karena fungsionalitas yang sama dapat dicapai dengan cara lain dan karena ini membersihkan menu banyak. Akan mengembalikan opsi-opsi tersebut jika orang mengeluh. Jadi jika Anda merindukan opsi-opsi tersebut - silakan mengeluh.
- Arah Klik dan Seret sekarang akan cocok dengan arah sapuan trackpad bahkan ketika "Scrolling natural" dimatikan di Pengaturan Sistem > Trackpad. Sebelumnya, Klik dan Seret selalu berperilaku seperti menggesek pada trackpad dengan "Scrolling natural" *aktif*.
- Memperbaiki masalah di mana kursor akan menghilang dan kemudian muncul kembali di tempat lain saat menggunakan Tindakan "Klik dan Seret" selama perekaman layar atau saat menggunakan perangkat lunak DisplayLink.
- Memperbaiki pemusatan "+" di Field "+" pada tab Tombol
- Beberapa Peningkatan visual pada tab tombol. Palet warna Field "+" dan Tabel Tindakan telah diubah agar terlihat benar saat menggunakan opsi "Allow wallpaper tinting in windows" macOS. Batas Tabel Tindakan sekarang memiliki warna transparan yang terlihat lebih dinamis dan menyesuaikan dengan lingkungannya.
- Membuat sehingga ketika Anda menambahkan banyak tindakan ke tabel tindakan dan jendela Mac Mouse Fix tumbuh, itu akan tumbuh tepat sebesar layar (atau sebesar layar minus dock jika Anda tidak mengaktifkan penyembunyian dock) dan kemudian berhenti. Ketika Anda menambahkan lebih banyak tindakan, tabel tindakan akan mulai bergulir.
- Beta ini sekarang mendukung checkout baru di mana Anda dapat membeli lisensi dalam dolar AS seperti yang diiklankan. Sebelumnya Anda hanya bisa membeli lisensi dalam Euro. Lisensi Euro lama tentu saja masih akan didukung.
- Memperbaiki masalah di mana scrolling momentum terkadang tidak dimulai saat menggunakan fitur "Scroll & Navigasi".
- Ketika jendela Mac Mouse Fix mengubah ukurannya sendiri selama pergantian tab, sekarang akan memposisikan ulang dirinya sehingga tidak tumpang tindih dengan Dock
- Memperbaiki kedipan pada beberapa elemen UI saat beralih dari tab Tombol ke tab lain
- Meningkatkan tampilan animasi yang dimainkan Field "+" setelah merekam input. Terutama pada versi macOS sebelum Ventura, di mana bayangan Field "+" akan muncul rusak selama animasi.
- Menonaktifkan notifikasi yang mencantumkan beberapa tombol yang telah ditangkap/tidak lagi ditangkap oleh Mac Mouse Fix yang akan muncul saat memulai aplikasi untuk pertama kalinya atau saat memuat preset. Saya pikir pesan-pesan ini mengganggu dan sedikit membingungkan dan tidak terlalu membantu dalam konteks tersebut.
- Mengerjakan ulang Layar Pemberian Akses Aksesibilitas. Sekarang akan menampilkan informasi tentang mengapa Mac Mouse Fix membutuhkan Akses Aksesibilitas secara inline alih-alih menautkan ke situs web dan sedikit lebih jelas dan memiliki tata letak yang lebih menarik secara visual.
- Memperbarui tautan Pengakuan pada tab Tentang.
- Meningkatkan pesan kesalahan ketika Mac Mouse Fix tidak dapat diaktifkan karena ada versi lain yang ada di sistem. Pesan sekarang akan ditampilkan di jendela peringatan mengambang yang selalu tetap di atas jendela lain sampai ditutup alih-alih Notifikasi Toast yang menghilang ketika mengklik di mana saja. Ini seharusnya memudahkan untuk mengikuti langkah-langkah solusi yang disarankan.
- Memperbaiki beberapa masalah dengan rendering markdown pada versi macOS sebelum Ventura. MMF sekarang akan menggunakan solusi rendering markdown kustom untuk semua Versi macOS, termasuk Ventura. Sebelumnya kami menggunakan API sistem yang diperkenalkan di Ventura tetapi itu menyebabkan ketidakkonsistenan. Markdown digunakan untuk menambahkan tautan dan penekanan ke teks di seluruh UI.
- Memperhalus interaksi seputar pengaktifan akses aksesibilitas.
- Memperbaiki masalah di mana jendela aplikasi terkadang terbuka tanpa menampilkan konten apa pun sampai Anda beralih ke salah satu tab.
- Memperbaiki masalah dengan Field "+" di mana terkadang Anda tidak bisa menambahkan tindakan baru meskipun menunjukkan efek hover yang menunjukkan bahwa Anda dapat memasukkan tindakan.
- Memperbaiki deadlock dan beberapa masalah kecil lainnya yang terkadang terjadi saat memindahkan pointer mouse di dalam Field "+"
- Memperbaiki masalah di mana popover yang muncul pada tab Tombol ketika mouse Anda tampaknya tidak sesuai dengan pengaturan tombol saat ini terkadang memiliki semua teks tebal.
- Memperbarui semua penyebutan lisensi MIT lama ke lisensi MMF baru. File baru yang dibuat untuk proyek sekarang akan berisi header yang dibuat otomatis yang menyebutkan lisensi MMF.
- Membuat peralihan ke tab Tombol mengaktifkan MMF untuk Scrolling. Jika tidak, Anda tidak bisa merekam gerakan Klik dan Scroll.
- Memperbaiki beberapa masalah di mana nama tombol tidak ditampilkan dengan benar di Tabel Tindakan dalam beberapa situasi.
- Memperbaiki bug di mana bagian uji coba pada layar Tentang akan terlihat buggy saat membuka aplikasi dan kemudian beralih ke tab uji coba setelah uji coba berakhir.
- Memperbaiki bug di mana tautan Aktifkan Lisensi di bagian uji coba Tab Tentang terkadang tidak bereaksi terhadap klik.
- Memperbaiki kebocoran memori saat menggunakan fitur "Klik dan Seret" untuk "Spaces & Mission Control".
- Mengaktifkan runtime yang Dikeraskan pada aplikasi Mac Mouse Fix utama, meningkatkan keamanan
- Banyak pembersihan kode, restrukturisasi proyek
- Beberapa crash lainnya diperbaiki
- Beberapa kebocoran memori diperbaiki
- Berbagai penyesuaian string UI kecil
- Pengerjaan ulang beberapa sistem internal juga meningkatkan ketangguhan dan perilaku dalam kasus-kasus tertentu

## 8. Bagaimana Anda Dapat Membantu

Anda dapat membantu dengan membagikan **ide**, **masalah** dan **umpan balik** Anda!

Tempat terbaik untuk membagikan **ide** dan **masalah** Anda adalah [Asisten Umpan Balik](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Tempat terbaik untuk memberikan umpan balik **cepat** yang tidak terstruktur adalah [Diskusi Umpan Balik](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Anda juga dapat mengakses tempat-tempat ini dari dalam aplikasi pada tab "**ⓘ Tentang**".

**Terima kasih** telah membantu membuat Mac Mouse Fix menjadi yang terbaik! 🙌:)