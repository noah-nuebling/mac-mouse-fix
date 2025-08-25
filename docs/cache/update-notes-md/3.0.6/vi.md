Mac Mouse Fix **3.0.6** cải thiện tính năng 'Quay lại' và 'Tiến tới' để tương thích với nhiều ứng dụng hơn.
Phiên bản này cũng khắc phục một số lỗi và sự cố.

### Cải thiện tính năng 'Quay lại' và 'Tiến tới'

Các phím chuột được gán chức năng 'Quay lại' và 'Tiến tới' giờ đây **hoạt động với nhiều ứng dụng hơn**, bao gồm:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed và các trình soạn thảo mã khác
- Nhiều ứng dụng tích hợp của Apple như Preview, Notes, System Settings, App Store và Music
- Adobe Acrobat
- Zotero
- Và nhiều ứng dụng khác!

Việc triển khai được lấy cảm hứng từ tính năng 'Universal Back and Forward' tuyệt vời trong [LinearMouse](https://github.com/linearmouse/linearmouse). Nó hỗ trợ tất cả các ứng dụng mà LinearMouse hỗ trợ. \
Hơn nữa, nó còn hỗ trợ một số ứng dụng thường yêu cầu phím tắt để quay lại và tiến tới, như System Settings, App Store, Apple Notes và Adobe Acrobat. Mac Mouse Fix sẽ phát hiện những ứng dụng này và mô phỏng các phím tắt thích hợp.

Mọi ứng dụng đã từng được [yêu cầu trong GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) giờ đều được hỗ trợ! (Cảm ơn phản hồi của mọi người!) \
Nếu bạn tìm thấy ứng dụng nào chưa hoạt động, hãy cho tôi biết trong phần [yêu cầu tính năng](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).

### Khắc phục lỗi 'Cuộn ngừng hoạt động không thường xuyên'

Một số người dùng gặp phải [sự cố](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) khi **cuộn mượt ngừng hoạt động** ngẫu nhiên.

Mặc dù tôi chưa thể tái hiện được sự cố này, tôi đã triển khai một bản sửa lỗi tiềm năng:

Ứng dụng sẽ thử lại nhiều lần khi việc thiết lập đồng bộ hóa màn hình thất bại. \
Nếu vẫn không hoạt động sau khi thử lại, ứng dụng sẽ:

- Khởi động lại tiến trình nền 'Mac Mouse Fix Helper', điều này có thể giải quyết vấn đề
- Tạo báo cáo sự cố, có thể giúp chẩn đoán lỗi

Tôi hy vọng vấn đề đã được giải quyết! Nếu không, hãy cho tôi biết trong [báo cáo lỗi](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) hoặc qua [email](http://redirect.macmousefix.com/?target=mailto-noah).

### Cải thiện hành vi con lăn cuộn tự do

Mac Mouse Fix sẽ **không còn tăng tốc độ cuộn** cho bạn khi bạn để con lăn cuộn quay tự do trên chuột MX Master. (Hoặc bất kỳ chuột nào khác có con lăn cuộn tự do.)

Mặc dù tính năng 'tăng tốc cuộn' này hữu ích trên các con lăn cuộn thông thường, nhưng trên con lăn cuộn tự do, nó có thể khiến việc kiểm soát trở nên khó khăn hơn.

**Lưu ý:** Mac Mouse Fix hiện không hoàn toàn tương thích với hầu hết các chuột Logitech, bao gồm cả MX Master. Tôi dự định thêm hỗ trợ đầy đủ, nhưng có thể sẽ mất một thời gian. Trong thời gian chờ đợi, trình điều khiển bên thứ ba tốt nhất có hỗ trợ Logitech mà tôi biết là [SteerMouse](https://plentycom.jp/en/steermouse/).

### Sửa lỗi

- Đã sửa lỗi Mac Mouse Fix đôi khi kích hoạt lại các phím tắt đã bị vô hiệu hóa trước đó trong System Settings
- Đã sửa lỗi crash khi nhấp vào 'Activate License'
- Đã sửa lỗi crash khi nhấp vào 'Cancel' ngay sau khi nhấp vào 'Activate License' (Cảm ơn báo cáo của bạn, Ali!)
- Đã sửa lỗi crash khi cố gắng sử dụng Mac Mouse Fix trong khi không có màn hình nào được kết nối với Mac
- Đã sửa lỗi rò rỉ bộ nhớ và một số vấn đề khác khi chuyển đổi giữa các tab trong ứng dụng

### Cải thiện hình ảnh

- Đã sửa lỗi tab About đôi khi quá cao, được giới thiệu trong [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Văn bản trên thông báo 'Free days are over' không còn bị cắt trong tiếng Trung
- Đã sửa lỗi hiển thị trên bóng của trường '+' sau khi ghi lại đầu vào
- Đã sửa lỗi hiếm gặp khi văn bản giữ chỗ trên màn hình 'Enter Your License Key' xuất hiện không căn giữa
- Đã sửa lỗi một số biểu tượng hiển thị trong ứng dụng có màu sắc sai sau khi chuyển đổi giữa chế độ tối/sáng

### Cải thiện khác

- Đã làm cho một số hiệu ứng, như hiệu ứng chuyển đổi tab, hiệu quả hơn một chút
- Đã vô hiệu hóa tính năng hoàn thành văn bản Touch Bar trên màn hình 'Enter Your License Key'
- Nhiều cải tiến nhỏ khác

*Được chỉnh sửa với sự hỗ trợ tuyệt vời của Claude.*

---

Đồng thời hãy xem phiên bản trước đó [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).