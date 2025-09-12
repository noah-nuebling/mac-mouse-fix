Mac Mouse Fix **3.0.7** đã khắc phục một số lỗi quan trọng.

### Sửa lỗi

- Ứng dụng hoạt động trở lại trên **các phiên bản macOS cũ hơn** (macOS 10.15 Catalina và macOS 11 Big Sur)
    - Mac Mouse Fix 3.0.6 không thể được kích hoạt trên những phiên bản macOS đó vì tính năng 'Quay lại' và 'Tiến tới' cải tiến được giới thiệu trong Mac Mouse Fix 3.0.6 đã cố gắng sử dụng các API hệ thống macOS chưa có sẵn.
- Đã sửa các vấn đề với tính năng **'Quay lại' và 'Tiến tới'**
    - Tính năng 'Quay lại' và 'Tiến tới' cải tiến được giới thiệu trong Mac Mouse Fix 3.0.6 giờ đây sẽ luôn sử dụng 'luồng chính' để hỏi macOS về việc nên giả lập nhấn phím nào để quay lại và tiến tới trong ứng dụng bạn đang sử dụng. \
    Điều này có thể ngăn chặn sự cố và hành vi không ổn định trong một số tình huống.
- Đã cố gắng sửa lỗi khiến **cài đặt bị đặt lại ngẫu nhiên** (Xem các [Vấn đề trên GitHub](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - Tôi đã viết lại mã tải tệp cấu hình cho Mac Mouse Fix để nó mạnh mẽ hơn. Khi xảy ra các lỗi hệ thống tệp hiếm gặp của macOS, mã cũ đôi khi có thể nhầm tưởng rằng tệp cấu hình bị hỏng và đặt lại về mặc định.
- Giảm khả năng xảy ra lỗi khiến **cuộn không hoạt động**
    - Lỗi này không thể được giải quyết hoàn toàn mà không cần những thay đổi sâu hơn, điều này có thể gây ra các vấn đề khác. \
    Tuy nhiên, hiện tại, tôi đã giảm khoảng thời gian có thể xảy ra 'deadlock' trong hệ thống cuộn, điều này ít nhất sẽ giảm khả năng gặp phải lỗi này. Điều này cũng làm cho việc cuộn hiệu quả hơn một chút.
    - Lỗi này có các triệu chứng tương tự – nhưng tôi nghĩ có nguyên nhân cơ bản khác – so với lỗi 'Cuộn Ngừng Hoạt Động Không Thường Xuyên' đã được giải quyết trong bản phát hành 3.0.6 trước đó.
    - (Cảm ơn Joonas về việc chẩn đoán!)

Cảm ơn mọi người đã báo cáo các lỗi!

---

Đồng thời hãy xem qua bản phát hành trước đó [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).