Mac Mouse Fix **3.0.4 Beta 1** cải thiện quyền riêng tư, hiệu quả và độ tin cậy.\
Phiên bản này giới thiệu hệ thống cấp phép ngoại tuyến mới và sửa nhiều lỗi quan trọng.

### Nâng cao Quyền riêng tư & Hiệu quả

- Giới thiệu hệ thống xác thực giấy phép ngoại tuyến mới giúp giảm thiểu kết nối internet.
- Ứng dụng giờ đây chỉ kết nối internet khi thực sự cần thiết, bảo vệ quyền riêng tư và giảm việc sử dụng tài nguyên.
- Ứng dụng hoạt động hoàn toàn ngoại tuyến trong quá trình sử dụng bình thường khi đã được cấp phép.

<details>
<summary><b>Thông tin Chi tiết về Quyền riêng tư</b></summary>
Các phiên bản trước xác thực giấy phép trực tuyến mỗi khi khởi động, có thể cho phép nhật ký kết nối được lưu trữ bởi máy chủ bên thứ ba (GitHub và Gumroad). Hệ thống mới loại bỏ các kết nối không cần thiết – sau khi kích hoạt giấy phép ban đầu, nó chỉ kết nối internet nếu dữ liệu giấy phép cục bộ bị hỏng.
<br><br>
Mặc dù tôi chưa bao giờ ghi lại hành vi người dùng, nhưng hệ thống trước đây về mặt lý thuyết cho phép máy chủ bên thứ ba ghi lại địa chỉ IP và thời gian kết nối. Gumroad cũng có thể ghi lại mã giấy phép của bạn và có thể liên kết nó với bất kỳ thông tin cá nhân nào họ ghi lại về bạn khi bạn mua Mac Mouse Fix.
<br><br>
Tôi đã không xem xét những vấn đề riêng tư tinh tế này khi xây dựng hệ thống cấp phép ban đầu, nhưng giờ đây, Mac Mouse Fix đã riêng tư và không cần internet nhất có thể!
<br><br>
Xem thêm <a href=https://gumroad.com/privacy>chính sách quyền riêng tư của Gumroad</a> và <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>bình luận trên GitHub</a> của tôi.

</details>

### Sửa lỗi

- Đã sửa lỗi khiến macOS đôi khi bị treo khi sử dụng 'Click and Drag' cho 'Spaces & Mission Control'.
- Đã sửa lỗi khiến phím tắt trong System Settings đôi khi bị xóa khi sử dụng hành động 'Click' được định nghĩa trong Mac Mouse Fix như 'Mission Control'.
- Đã sửa [lỗi](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) khiến ứng dụng đôi khi ngừng hoạt động và hiển thị thông báo 'Free days are over' cho người dùng đã mua ứng dụng.
    - Nếu bạn gặp phải lỗi này, tôi chân thành xin lỗi vì sự bất tiện. Bạn có thể yêu cầu [hoàn tiền tại đây](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).

### Cải tiến Kỹ thuật

- Triển khai hệ thống 'MFDataClass' mới cho phép mô hình hóa dữ liệu sạch hơn và tệp cấu hình có thể đọc được.
- Xây dựng hỗ trợ để thêm các nền tảng thanh toán khác ngoài Gumroad. Vì vậy trong tương lai, có thể có thanh toán được bản địa hóa, và ứng dụng có thể được bán cho các quốc gia khác nhau!

### Ngừng Hỗ trợ (Không chính thức) cho macOS 10.14 Mojave

Mac Mouse Fix 3 chính thức hỗ trợ macOS 11 Big Sur trở lên. Tuy nhiên, đối với người dùng sẵn sàng chấp nhận một số lỗi và vấn đề đồ họa, Mac Mouse Fix 3.0.3 và các phiên bản trước đó vẫn có thể được sử dụng trên macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 ngừng hỗ trợ đó và **giờ đây yêu cầu macOS 10.15 Catalina**.\
Tôi xin lỗi vì bất kỳ sự bất tiện nào do điều này gây ra. Thay đổi này cho phép tôi triển khai hệ thống cấp phép cải tiến bằng các tính năng Swift hiện đại. Người dùng Mojave có thể tiếp tục sử dụng Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) hoặc [phiên bản mới nhất của Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Tôi hy vọng đó là giải pháp tốt cho tất cả mọi người.

*Chỉnh sửa với sự hỗ trợ tuyệt vời từ Claude.*

---

Xem thêm phiên bản trước đó [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).