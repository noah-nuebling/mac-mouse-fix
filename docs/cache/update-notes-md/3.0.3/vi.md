Mac Mouse Fix **3.0.3** đã sẵn sàng cho macOS 15 Sequoia. Phiên bản này cũng khắc phục một số vấn đề về tính ổn định và cung cấp nhiều cải tiến nhỏ.

### Hỗ trợ macOS 15 Sequoia

Ứng dụng giờ đã hoạt động tốt trên macOS 15 Sequoia!

- Hầu hết các hiệu ứng UI bị lỗi trên macOS 15 Sequoia. Giờ đây mọi thứ đã hoạt động bình thường trở lại!
- Mã nguồn giờ đã có thể biên dịch được trên macOS 15 Sequoia. Trước đây, có các vấn đề với trình biên dịch Swift khiến ứng dụng không thể biên dịch được.

### Xử lý các sự cố crash khi cuộn

Kể từ Mac Mouse Fix 3.0.2, đã có [nhiều báo cáo](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) về việc Mac Mouse Fix định kỳ tự tắt và bật lại trong khi cuộn. Điều này do sự cố crash của ứng dụng nền 'Mac Mouse Fix Helper'. Bản cập nhật này cố gắng khắc phục các sự cố crash này với những thay đổi sau:

- Cơ chế cuộn sẽ cố gắng phục hồi và tiếp tục chạy thay vì crash khi gặp phải trường hợp đặc biệt dường như đã dẫn đến những sự cố crash này.
- Tôi đã thay đổi cách xử lý các trạng thái không mong đợi trong ứng dụng một cách tổng quát hơn: Thay vì luôn crash ngay lập tức, ứng dụng giờ đây sẽ cố gắng phục hồi từ các trạng thái không mong đợi trong nhiều trường hợp.
    
    - Thay đổi này góp phần vào việc khắc phục các sự cố crash khi cuộn được mô tả ở trên. Nó cũng có thể ngăn chặn các sự cố crash khác.

Lưu ý: Tôi không thể tái hiện được các sự cố crash này trên máy của mình và vẫn chưa chắc chắn nguyên nhân gây ra chúng, nhưng dựa trên các báo cáo tôi nhận được, bản cập nhật này sẽ ngăn chặn mọi sự cố crash. Nếu bạn vẫn gặp sự cố crash khi cuộn hoặc bạn *đã* gặp sự cố crash trong phiên bản 3.0.2, sẽ rất hữu ích nếu bạn chia sẻ trải nghiệm và dữ liệu chẩn đoán của mình trong GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). Điều này sẽ giúp tôi hiểu vấn đề và cải thiện Mac Mouse Fix. Cảm ơn bạn!

### Xử lý hiện tượng giật khi cuộn

Trong phiên bản 3.0.2, tôi đã thực hiện các thay đổi về cách Mac Mouse Fix gửi các sự kiện cuộn đến hệ thống nhằm giảm hiện tượng giật có thể do vấn đề với các API VSync của Apple.

Tuy nhiên, sau khi kiểm tra kỹ lưỡng hơn và nhận được phản hồi, có vẻ như cơ chế mới trong 3.0.2 làm cho việc cuộn mượt mà hơn trong một số tình huống nhưng lại gây giật nhiều hơn trong các trường hợp khác. Đặc biệt là trên Firefox, tình trạng dường như tệ hơn đáng kể. \
Nhìn chung, không rõ liệu cơ chế mới có thực sự cải thiện hiện tượng giật khi cuộn hay không. Ngoài ra, nó có thể đã góp phần gây ra các sự cố crash khi cuộn được mô tả ở trên.

Vì vậy, tôi đã vô hiệu hóa cơ chế mới và khôi phục lại cơ chế VSync cho các sự kiện cuộn về như trong Mac Mouse Fix 3.0.0 và 3.0.1.

Xem GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) để biết thêm thông tin.

### Hoàn tiền

Tôi xin lỗi về các rắc rối liên quan đến những thay đổi về cuộn trong phiên bản 3.0.1 và 3.0.2. Tôi đã đánh giá quá thấp các vấn đề sẽ phát sinh từ điều đó và đã chậm trễ trong việc giải quyết những vấn đề này. Tôi sẽ cố gắng hết sức để rút kinh nghiệm từ trải nghiệm này và thận trọng hơn với những thay đổi tương tự trong tương lai. Tôi cũng muốn đề nghị hoàn tiền cho bất kỳ ai bị ảnh hưởng. Chỉ cần nhấp vào [đây](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) nếu bạn quan tâm.

### Cơ chế cập nhật thông minh hơn

Những thay đổi này được chuyển từ Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) và [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Xem ghi chú phát hành của chúng để tìm hiểu thêm về chi tiết. Dưới đây là tóm tắt:

- Có một cơ chế mới, thông minh hơn để quyết định hiển thị bản cập nhật nào cho người dùng.
- Chuyển từ sử dụng framework cập nhật Sparkle 1.26.0 sang Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3) mới nhất.
- Cửa sổ mà ứng dụng hiển thị để thông báo cho bạn về phiên bản mới của Mac Mouse Fix giờ đây hỗ trợ JavaScript, cho phép định dạng ghi chú cập nhật đẹp hơn.

### Các Cải tiến & Sửa lỗi Khác

- Đã sửa lỗi khiến giá ứng dụng và thông tin liên quan hiển thị không chính xác trên tab 'About' trong một số trường hợp.
- Đã sửa lỗi khiến cơ chế đồng bộ hóa cuộn mượt với tốc độ làm mới màn hình không hoạt động đúng khi sử dụng nhiều màn hình.
- Nhiều cải tiến và dọn dẹp nhỏ dưới nền.

---

Đồng thời hãy xem phiên bản trước đó [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).