Mac Mouse Fix **3.0.5** sửa nhiều lỗi, cải thiện hiệu suất và làm cho ứng dụng hoàn thiện hơn. \
Nó cũng tương thích với macOS 26 Tahoe.

### Cải thiện Mô phỏng Cuộn Trackpad

- Hệ thống cuộn giờ đây có thể mô phỏng thao tác chạm hai ngón tay trên trackpad để làm cho ứng dụng dừng cuộn.
    - Điều này sửa một vấn đề khi chạy ứng dụng iPhone hoặc iPad, khi mà việc cuộn thường tiếp tục sau khi người dùng chọn dừng lại.
- Đã sửa lỗi mô phỏng không nhất quán khi nhấc ngón tay khỏi trackpad.
    - Điều này có thể đã gây ra hành vi không tối ưu trong một số tình huống.



### Tương thích với macOS 26 Tahoe

Khi chạy bản Beta macOS 26 Tahoe, ứng dụng giờ đã có thể sử dụng được và hầu hết giao diện người dùng hoạt động chính xác.



### Cải thiện Hiệu suất

Cải thiện hiệu suất của cử chỉ Nhấp và Kéo để "Cuộn & Điều hướng". \
Trong quá trình kiểm tra của tôi, mức sử dụng CPU đã giảm khoảng 50%!

**Thông tin chi tiết**

Trong cử chỉ "Cuộn & Điều hướng", Mac Mouse Fix vẽ một con trỏ chuột giả trong cửa sổ trong suốt, trong khi khóa con trỏ chuột thật tại chỗ. Điều này đảm bảo rằng bạn có thể tiếp tục cuộn phần tử giao diện mà bạn bắt đầu cuộn, bất kể bạn di chuyển chuột xa đến đâu.

Hiệu suất được cải thiện bằng cách tắt xử lý sự kiện mặc định của macOS trên cửa sổ trong suốt này, vốn không được sử dụng.





### Sửa lỗi

- Giờ đây bỏ qua các sự kiện cuộn từ bảng vẽ Wacom.
    - Trước đây, Mac Mouse Fix gây ra cuộn bất thường trên các bảng vẽ Wacom, như được báo cáo bởi @frenchie1980 trong GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Cảm ơn!)
    
- Đã sửa lỗi mã Swift Concurrency, được giới thiệu như một phần của hệ thống cấp phép mới trong Mac Mouse Fix 3.0.4, không chạy trên thread chính xác.
    - Điều này gây ra crash trên macOS Tahoe, và có thể cũng gây ra các lỗi ngẫu nhiên khác liên quan đến cấp phép.
- Cải thiện độ ổn định của mã giải mã giấy phép ngoại tuyến.
    - Điều này giải quyết một vấn đề trong API của Apple khiến việc xác thực giấy phép ngoại tuyến luôn thất bại trên Mac Mini Intel của tôi. Tôi cho rằng điều này xảy ra trên tất cả các Mac Intel, và đó là lý do tại sao lỗi "Hết ngày dùng thử" (đã được giải quyết trong 3.0.4) vẫn xảy ra với một số người, như được báo cáo bởi @toni20k5267 trong GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Cảm ơn bạn!)
        - Nếu bạn gặp phải lỗi "Hết ngày dùng thử", tôi xin lỗi về điều đó! Bạn có thể nhận hoàn tiền [tại đây](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).
     
     

### Cải thiện Trải nghiệm Người dùng

- Đã tắt các hộp thoại cung cấp giải pháp từng bước cho các lỗi macOS ngăn người dùng kích hoạt Mac Mouse Fix.
    - Những vấn đề này chỉ xảy ra trên macOS 13 Ventura và 14 Sonoma. Giờ đây, những hộp thoại này chỉ xuất hiện trên các phiên bản macOS có liên quan.
    - Các hộp thoại cũng khó kích hoạt hơn một chút - trước đây, chúng đôi khi xuất hiện trong những tình huống không thực sự hữu ích.
    
- Thêm liên kết "Kích hoạt Giấy phép" trực tiếp trên thông báo "Hết ngày dùng thử".
    - Điều này làm cho việc kích hoạt giấy phép Mac Mouse Fix càng dễ dàng hơn!

### Cải thiện Hình ảnh

- Cải thiện nhẹ giao diện của cửa sổ "Cập nhật Phần mềm". Giờ đây nó phù hợp hơn với macOS 26 Tahoe.
    - Điều này được thực hiện bằng cách tùy chỉnh giao diện mặc định của framework "Sparkle 1.27.3" mà Mac Mouse Fix sử dụng để xử lý cập nhật.
- Đã sửa lỗi văn bản ở cuối tab Giới thiệu đôi khi bị cắt trong tiếng Trung, bằng cách làm cho cửa sổ rộng hơn một chút.
- Đã sửa lỗi văn bản ở cuối tab Giới thiệu bị lệch tâm một chút.
- Đã sửa lỗi khiến khoảng trống dưới tùy chọn "Phím tắt..." trên tab Nút quá nhỏ.

### Thay đổi Bên trong

- Đã loại bỏ phụ thuộc vào framework "SnapKit".
    - Điều này giảm nhẹ kích thước của ứng dụng từ 19.8 xuống 19.5 MB.
- Nhiều cải tiến nhỏ khác trong mã nguồn.

*Được chỉnh sửa với sự hỗ trợ tuyệt vời từ Claude.*

---

Hãy xem thêm phiên bản trước đó [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).