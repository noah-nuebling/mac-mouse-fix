Đồng thời hãy xem qua những **thay đổi tuyệt vời** được giới thiệu trong [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** khôi phục **khả năng tương thích** với một số **chuột** trên macOS 13 Ventura và **sửa chức năng cuộn** trong nhiều ứng dụng.
Nó cũng bao gồm một số sửa lỗi nhỏ và cải tiến chất lượng khác.

Đây là **tất cả những điều mới**:

### Chuột

- Đã sửa chức năng cuộn trong Terminal và các ứng dụng khác! Xem GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Đã sửa vấn đề không tương thích với một số chuột trên macOS 13 Ventura bằng cách chuyển từ việc sử dụng API Apple không đáng tin cậy sang các hack cấp thấp. Hy vọng điều này không gây ra vấn đề mới - hãy cho tôi biết nếu có! Cảm ơn đặc biệt đến Maria và người dùng GitHub [samiulhsnt](https://github.com/samiulhsnt) đã giúp tìm ra giải pháp! Xem GitHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) để biết thêm thông tin.
- Sẽ không sử dụng CPU khi nhấp Nút Chuột 1 hoặc 2 nữa. Giảm nhẹ mức sử dụng CPU khi nhấp các nút khác.
    - Đây là "Bản Dựng Gỡ Lỗi" nên mức sử dụng CPU có thể cao hơn khoảng 10 lần khi nhấp nút trong bản beta này so với bản phát hành chính thức
- Mô phỏng cuộn trackpad được sử dụng cho tính năng "Cuộn Mượt" và "Cuộn & Điều Hướng" của Mac Mouse Fix giờ đây còn chính xác hơn. Điều này có thể dẫn đến hoạt động tốt hơn trong một số tình huống.

### Giao diện người dùng

- Tự động sửa các vấn đề với việc cấp Quyền truy cập Accessibility sau khi cập nhật từ phiên bản cũ của Mac Mouse Fix. Áp dụng các thay đổi được mô tả trong [Ghi chú Phát hành 2.2.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Thêm nút "Hủy" vào màn hình "Cấp Quyền truy cập Accessibility"
- Đã sửa lỗi cấu hình Mac Mouse Fix không hoạt động đúng sau khi cài đặt phiên bản mới của Mac Mouse Fix, vì phiên bản mới sẽ kết nối với phiên bản cũ của "Mac Mouse Fix Helper". Giờ đây, Mac Mouse Fix sẽ không kết nối với "Mac Mouse Fix Helper" cũ nữa và tự động vô hiệu hóa phiên bản cũ khi cần thiết.
- Cung cấp hướng dẫn cho người dùng cách khắc phục vấn đề khi Mac Mouse Fix không thể được kích hoạt đúng cách do có phiên bản Mac Mouse Fix khác trong hệ thống. Vấn đề này chỉ xảy ra trên macOS Ventura.
- Cải thiện hành vi và hiệu ứng trên màn hình "Cấp Quyền truy cập Accessibility"
- Mac Mouse Fix sẽ được đưa lên nền trước khi được kích hoạt. Điều này cải thiện tương tác giao diện người dùng trong một số tình huống như khi bạn kích hoạt Mac Mouse Fix sau khi nó bị vô hiệu hóa trong System Settings > General > Login Items.
- Cải thiện chuỗi giao diện người dùng trên màn hình "Cấp Quyền truy cập Accessibility"
- Cải thiện chuỗi giao diện người dùng hiển thị khi cố gắng kích hoạt Mac Mouse Fix trong khi nó bị vô hiệu hóa trong System Settings
- Đã sửa một chuỗi giao diện người dùng tiếng Đức

### Bên dưới nắp capo

- Số phiên bản của "Mac Mouse Fix" và "Mac Mouse Fix Helper" nhúng giờ đã được đồng bộ hóa. Điều này được sử dụng để ngăn "Mac Mouse Fix" vô tình kết nối với các phiên bản cũ của "Mac Mouse Fix Helper".
- Đã sửa lỗi một số dữ liệu về giấy phép và thời gian dùng thử đôi khi hiển thị không chính xác khi khởi động ứng dụng lần đầu tiên bằng cách xóa dữ liệu cache khỏi cấu hình ban đầu
- Dọn dẹp nhiều trong cấu trúc dự án và mã nguồn
- Cải thiện thông báo gỡ lỗi

---

### Cách Bạn Có Thể Giúp đỡ

Bạn có thể giúp đỡ bằng cách chia sẻ **ý tưởng**, **vấn đề** và **phản hồi** của bạn!

Nơi tốt nhất để chia sẻ **ý tưởng** và **vấn đề** là [Trợ lý Phản hồi](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
Nơi tốt nhất để đưa ra phản hồi **nhanh** không có cấu trúc là [Thảo luận Phản hồi](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

Bạn cũng có thể truy cập những nơi này từ trong ứng dụng trên tab "**ⓘ Giới thiệu**".

**Cảm ơn** vì đã giúp Mac Mouse Fix trở nên tốt hơn! 💙💛❤️