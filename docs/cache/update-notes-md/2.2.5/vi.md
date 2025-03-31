Mac Mouse Fix **2.2.5** có những cải tiến về cơ chế cập nhật và đã sẵn sàng cho macOS 15 Sequoia!

### Khung cập nhật Sparkle mới

Mac Mouse Fix sử dụng khung cập nhật [Sparkle](https://sparkle-project.org/) để cung cấp trải nghiệm cập nhật tốt hơn.

Với phiên bản 2.2.5, Mac Mouse Fix chuyển từ Sparkle 1.26.0 sang phiên bản mới nhất [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), bao gồm các bản vá bảo mật, cải tiến bản địa hóa và nhiều tính năng khác.

### Cơ chế cập nhật thông minh hơn

Có một cơ chế mới quyết định bản cập nhật nào sẽ hiển thị cho người dùng. Hành vi đã thay đổi theo những cách sau:

1. Sau khi bạn bỏ qua một bản cập nhật **chính** (ví dụ như 2.2.5 -> 3.0.0), bạn vẫn sẽ nhận được thông báo về các bản cập nhật **nhỏ** (ví dụ như 2.2.5 -> 2.2.6).
    - Điều này cho phép bạn dễ dàng tiếp tục sử dụng Mac Mouse Fix 2 trong khi vẫn nhận được các bản cập nhật, như đã thảo luận trong GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Thay vì hiển thị bản cập nhật mới nhất, Mac Mouse Fix giờ đây sẽ hiển thị cho bạn bản cập nhật đầu tiên của phiên bản chính mới nhất.
    - Ví dụ: Nếu bạn đang sử dụng MMF 2.2.5, và MMF 3.4.5 là phiên bản mới nhất, ứng dụng sẽ hiển thị cho bạn phiên bản đầu tiên của MMF 3 (3.0.0), thay vì phiên bản mới nhất (3.4.5). Bằng cách này, tất cả người dùng MMF 2.2.5 sẽ thấy changelog của MMF 3.0.0 trước khi chuyển sang MMF 3.
    - Thảo luận:
        - Động lực chính đằng sau điều này là, đầu năm nay, nhiều người dùng MMF 2 đã cập nhật trực tiếp từ MMF 2 lên MMF 3.0.1 hoặc 3.0.2. Vì họ chưa bao giờ thấy changelog của 3.0.0, họ đã bỏ lỡ thông tin về những thay đổi về giá cả giữa MMF 2 và MMF 3 (MMF 3 không còn hoàn toàn miễn phí). Vì vậy khi MMF 3 đột nhiên yêu cầu họ phải trả tiền để tiếp tục sử dụng ứng dụng, một số người đã - một cách dễ hiểu - hơi bối rối và khó chịu.
        - Nhược điểm: Nếu bạn chỉ muốn cập nhật lên phiên bản mới nhất, bây giờ bạn sẽ phải cập nhật hai lần trong một số trường hợp. Điều này hơi kém hiệu quả, nhưng nó vẫn chỉ mất vài giây. Và vì điều này làm cho các thay đổi giữa các phiên bản chính minh bạch hơn nhiều, tôi nghĩ đây là một sự đánh đổi hợp lý.

### Hỗ trợ macOS 15 Sequoia

Mac Mouse Fix 2.2.5 sẽ hoạt động tốt trên macOS 15 Sequoia mới - giống như phiên bản 2.2.4.

---

Hãy xem thêm phiên bản trước đó [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*Nếu bạn gặp khó khăn trong việc kích hoạt Mac Mouse Fix sau khi cập nhật, vui lòng xem ['Hướng dẫn Kích hoạt Mac Mouse Fix'](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*