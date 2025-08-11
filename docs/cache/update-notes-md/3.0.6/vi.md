**ℹ️ Lưu ý cho người dùng Mac Mouse Fix 2**

Với sự ra mắt của Mac Mouse Fix 3, mô hình giá của ứng dụng đã thay đổi:

- **Mac Mouse Fix 2**\
Vẫn hoàn toàn miễn phí, và tôi dự định sẽ tiếp tục hỗ trợ nó.\
**Bỏ qua bản cập nhật này** để tiếp tục sử dụng Mac Mouse Fix 2. Tải về phiên bản mới nhất của Mac Mouse Fix 2 [tại đây](https://redirect.macmousefix.com/?target=mmf2-latest).
- **Mac Mouse Fix 3**\
Miễn phí trong 30 ngày, sau đó tốn một vài đô la để sở hữu.\
**Cập nhật ngay** để có Mac Mouse Fix 3!

Bạn có thể tìm hiểu thêm về giá cả và tính năng của Mac Mouse Fix 3 trên [trang web mới](https://macmousefix.com/).

Cảm ơn bạn đã sử dụng Mac Mouse Fix! :)

---

**ℹ️ Lưu ý cho người mua Mac Mouse Fix 3**

Nếu bạn vô tình cập nhật lên Mac Mouse Fix 3 mà không biết rằng nó không còn miễn phí nữa, tôi muốn đề nghị [hoàn tiền](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) cho bạn.

Phiên bản mới nhất của Mac Mouse Fix 2 vẫn **hoàn toàn miễn phí**, và bạn có thể tải về [tại đây](https://redirect.macmousefix.com/?target=mmf2-latest).

Tôi xin lỗi vì sự bất tiện này và hy vọng mọi người đều đồng ý với giải pháp này!

---

Mac Mouse Fix **3.0.6** giúp tính năng 'Quay lại' và 'Tiến tới' tương thích với nhiều ứng dụng hơn.
Nó cũng khắc phục một số lỗi và vấn đề.

### Cải thiện khả năng tương thích 'Quay lại' và 'Tiến tới'

Các phím chuột được gán chức năng 'Quay lại' và 'Tiến tới' giờ đây **hoạt động với nhiều ứng dụng hơn**, bao gồm:
- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed, và các trình soạn thảo mã khác
- Nhiều ứng dụng tích hợp của Apple như Preview, Notes, System Settings, App Store, Music, TV, Books, và Freeform
- Adobe Acrobat
- Zotero
- Và nhiều hơn nữa!

Việc triển khai được lấy cảm hứng từ tính năng 'Universal Back and Forward' tuyệt vời trong [LinearMouse](https://github.com/linearmouse/linearmouse). Nó sẽ hỗ trợ tất cả các ứng dụng mà LinearMouse hỗ trợ. \
Hơn nữa, nó còn hỗ trợ một số ứng dụng thường yêu cầu phím tắt để quay lại và tiến tới, như System Settings, App Store, Apple Notes, và Adobe Acrobat. Mac Mouse Fix sẽ phát hiện những ứng dụng đó và mô phỏng các phím tắt thích hợp.

Mọi ứng dụng đã từng được [yêu cầu trong GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) giờ đều được hỗ trợ! (Cảm ơn phản hồi của các bạn!)
Nếu bạn tìm thấy bất kỳ ứng dụng nào chưa hoạt động, hãy cho tôi biết trong [yêu cầu tính năng](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).

### Giải quyết lỗi 'Cuộn bị dừng không đều'

Một số người dùng gặp phải [vấn đề](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) khi **cuộn mượt bị dừng** ngẫu nhiên.

Mặc dù tôi chưa thể tái hiện vấn đề này, tôi đã triển khai một bản sửa lỗi tiềm năng:

Ứng dụng sẽ thử lại nhiều lần khi việc thiết lập đồng bộ hóa màn hình thất bại. \
Nếu vẫn không hoạt động sau khi thử lại, ứng dụng sẽ:
- Khởi động lại tiến trình nền 'Mac Mouse Fix Helper', có thể giải quyết vấn đề
- Tạo báo cáo sự cố, có thể giúp chẩn đoán lỗi

Tôi hy vọng vấn đề đã được khắc phục! Nếu không, hãy cho tôi biết trong [báo cáo lỗi](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) hoặc qua [email](http://redirect.macmousefix.com/?target=mailto-noah).

### Cải thiện hành vi con lăn cuộn tự do

Mac Mouse Fix sẽ **không còn tăng tốc độ cuộn cho bạn** khi bạn để con lăn cuộn quay tự do trên chuột MX Master. (Hoặc bất kỳ chuột nào khác có con lăn cuộn tự do.)

Mặc dù tính năng 'tăng tốc cuộn' này hữu ích trên các con lăn cuộn thông thường, nhưng trên con lăn cuộn tự do, nó có thể khiến việc kiểm soát trở nên khó khăn hơn.

**Lưu ý:** Mac Mouse Fix hiện không hoàn toàn tương thích với hầu hết các chuột Logitech, bao gồm cả MX Master. Tôi dự định thêm hỗ trợ đầy đủ, nhưng có thể sẽ mất một thời gian. Trong thời gian chờ đợi, trình điều khiển bên thứ ba tốt nhất có hỗ trợ Logitech mà tôi biết là [SteerMouse](https://plentycom.jp/en/steermouse/).

### Sửa lỗi

- Đã sửa lỗi Mac Mouse Fix đôi khi kích hoạt lại các phím tắt đã bị vô hiệu hóa trước đó trong System Settings
- Đã sửa lỗi crash khi nhấp vào 'Kích hoạt Giấy phép'
- Đã sửa lỗi crash khi nhấp vào 'Hủy' ngay sau khi nhấp vào 'Kích hoạt Giấy phép' (Cảm ơn báo cáo của bạn, Ali!)
- Đã sửa lỗi crash khi cố gắng sử dụng Mac Mouse Fix trong khi không có màn hình nào được kết nối với Mac của bạn
- Đã sửa lỗi rò rỉ bộ nhớ và một số vấn đề khác khi chuyển đổi giữa các tab trong ứng dụng

### Cải thiện hình ảnh

- Đã sửa lỗi tab About đôi khi quá cao, được giới thiệu trong [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Văn bản trên thông báo 'Hết ngày dùng thử' không còn bị cắt trong tiếng Trung
- Đã sửa lỗi hiển thị về bóng của trường '+' sau khi ghi lại đầu vào
- Đã sửa lỗi hiếm gặp khi văn bản giữ chỗ trên màn hình 'Nhập Khóa Giấy Phép' xuất hiện không căn giữa
- Đã vô hiệu hóa tự động hoàn thành văn bản Touch Bar trên màn hình 'Nhập Khóa Giấy Phép'
- Đã sửa lỗi một số ký hiệu hiển thị trong ứng dụng có màu sắc không đúng sau khi chuyển đổi giữa chế độ tối/sáng

### Cải thiện khác

- Đã làm cho một số hoạt ảnh, như hoạt ảnh chuyển đổi tab, hiệu quả hơn một chút
- Nhiều cải tiến nhỏ khác dưới nền tảng

*Được chỉnh sửa với sự hỗ trợ tuyệt vời của Claude.*

---

Đồng thời hãy xem phiên bản trước đó [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)