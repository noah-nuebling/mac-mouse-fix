Mac Mouse Fix **3.0.4** cải thiện quyền riêng tư, hiệu quả và độ tin cậy.\
Phiên bản này giới thiệu hệ thống cấp phép ngoại tuyến mới và sửa nhiều lỗi quan trọng.

### Nâng cao Quyền riêng tư & Hiệu quả

3.0.4 giới thiệu hệ thống xác thực giấy phép ngoại tuyến mới giảm thiểu kết nối internet tối đa có thể.\
Điều này cải thiện quyền riêng tư và tiết kiệm tài nguyên hệ thống máy tính của bạn.\
Khi đã được cấp phép, ứng dụng giờ đây hoạt động 100% ngoại tuyến!

<details>
<summary><b>Nhấp vào đây để xem thêm chi tiết</b></summary>
Các phiên bản trước xác thực giấy phép trực tuyến mỗi khi khởi động, có thể cho phép nhật ký kết nối được lưu trữ bởi máy chủ bên thứ ba (GitHub và Gumroad). Hệ thống mới loại bỏ các kết nối không cần thiết – sau khi kích hoạt giấy phép ban đầu, nó chỉ kết nối internet nếu dữ liệu giấy phép cục bộ bị hỏng.
<br><br>
Mặc dù tôi chưa bao giờ ghi lại hành vi người dùng, nhưng về mặt lý thuyết, hệ thống trước đây cho phép máy chủ của bên thứ ba ghi lại địa chỉ IP và thời gian kết nối. Gumroad cũng có thể ghi lại mã giấy phép của bạn và có khả năng liên kết nó với bất kỳ thông tin cá nhân nào họ ghi lại về bạn khi bạn mua Mac Mouse Fix.
<br><br>
Tôi đã không xem xét những vấn đề riêng tư tinh tế này khi xây dựng hệ thống cấp phép ban đầu, nhưng giờ đây, Mac Mouse Fix đã riêng tư và không cần internet nhất có thể!
<br><br>
Xem thêm <a href=https://gumroad.com/privacy>chính sách quyền riêng tư của Gumroad</a> và <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>bình luận trên GitHub</a> của tôi.

</details>

### Sửa lỗi

- Đã sửa lỗi đôi khi macOS bị treo khi sử dụng 'Click and Drag' cho 'Spaces & Mission Control'.
- Đã sửa lỗi đôi khi phím tắt trong Cài đặt Hệ thống bị xóa khi sử dụng các thao tác 'Click' của Mac Mouse Fix như 'Mission Control'.
- Đã sửa [lỗi](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) khiến ứng dụng đôi khi ngừng hoạt động và hiển thị thông báo 'Hết ngày dùng thử' cho người dùng đã mua ứng dụng.
    - Nếu bạn gặp phải lỗi này, tôi chân thành xin lỗi vì sự bất tiện. Bạn có thể yêu cầu [hoàn tiền tại đây](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund).
- Cải thiện cách ứng dụng truy xuất cửa sổ chính, có thể đã sửa lỗi màn hình 'Kích hoạt Giấy phép' đôi khi không xuất hiện.

### Cải thiện Khả năng sử dụng

- Đã vô hiệu hóa việc nhập dấu cách và xuống dòng trong trường văn bản trên màn hình 'Kích hoạt Giấy phép'.
    - Đây là điểm gây nhầm lẫn phổ biến, vì rất dễ vô tình chọn một dấu xuống dòng ẩn khi sao chép mã giấy phép từ email của Gumroad.
- Những ghi chú cập nhật này được tự động dịch cho người dùng không nói tiếng Anh (Được hỗ trợ bởi Claude). Tôi hy vọng điều này hữu ích! Nếu bạn gặp bất kỳ vấn đề gì, hãy cho tôi biết. Đây là cái nhìn đầu tiên về hệ thống dịch thuật mới mà tôi đã phát triển trong năm qua.

### Ngừng Hỗ trợ (Không chính thức) cho macOS 10.14 Mojave

Mac Mouse Fix 3 chính thức hỗ trợ macOS 11 Big Sur trở lên. Tuy nhiên, đối với người dùng sẵn sàng chấp nhận một số lỗi và vấn đề đồ họa, Mac Mouse Fix 3.0.3 và các phiên bản trước vẫn có thể được sử dụng trên macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 ngừng hỗ trợ đó và **giờ đây yêu cầu macOS 10.15 Catalina**.\
Tôi xin lỗi vì bất kỳ sự bất tiện nào do điều này gây ra. Thay đổi này cho phép tôi triển khai hệ thống cấp phép cải tiến bằng các tính năng Swift hiện đại. Người dùng Mojave có thể tiếp tục sử dụng Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) hoặc [phiên bản mới nhất của Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). Tôi hy vọng đây là giải pháp tốt cho tất cả mọi người.

### Cải tiến Bên trong

- Triển khai hệ thống 'MFDataClass' mới cho phép mô hình hóa dữ liệu mạnh mẽ hơn trong khi vẫn giữ tệp cấu hình của Mac Mouse Fix có thể đọc và chỉnh sửa được bởi con người.
- Xây dựng hỗ trợ để thêm các nền tảng thanh toán khác ngoài Gumroad. Vì vậy trong tương lai, có thể có thanh toán được bản địa hóa, và ứng dụng có thể được bán cho các quốc gia khác nhau.
- Cải thiện ghi nhật ký cho phép tôi tạo "Bản dựng Gỡ lỗi" hiệu quả hơn cho người dùng gặp phải lỗi khó tái hiện.
- Nhiều cải tiến nhỏ khác và công việc dọn dẹp.

*Được chỉnh sửa với sự hỗ trợ tuyệt vời từ Claude.*

---

Đồng thời kiểm tra phiên bản trước đó [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).