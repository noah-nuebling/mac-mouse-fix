Mac Mouse Fix **2.2.1** cung cấp **hỗ trợ đầy đủ cho macOS Ventura** cùng nhiều thay đổi khác.

### Hỗ trợ Ventura!
Mac Mouse Fix giờ đây hỗ trợ đầy đủ và hoạt động tự nhiên trên macOS 13 Ventura.
Cảm ơn đặc biệt tới [@chamburr](https://github.com/chamburr) đã giúp đỡ với việc hỗ trợ Ventura trong GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Các thay đổi bao gồm:

- Cập nhật giao diện cấp quyền Truy cập để phù hợp với Cài đặt Hệ thống mới của Ventura
- Mac Mouse Fix sẽ hiển thị đúng cách trong menu **Cài đặt Hệ thống > Các mục Đăng nhập** mới của Ventura
- Mac Mouse Fix sẽ phản ứng đúng cách khi bị tắt trong **Cài đặt Hệ thống > Các mục Đăng nhập**

### Ngừng hỗ trợ các phiên bản macOS cũ hơn

Đáng tiếc là Apple chỉ cho phép phát triển _cho_ macOS 10.13 **High Sierra trở lên** khi phát triển _từ_ macOS 13 Ventura.

Vì vậy **phiên bản tối thiểu được hỗ trợ** đã tăng từ 10.11 El Capitan lên 10.13 High Sierra.

### Sửa lỗi

- Đã sửa lỗi khiến Mac Mouse Fix thay đổi hành vi cuộn của một số **bảng vẽ**. Xem GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Đã sửa lỗi khiến **phím tắt** có phím 'A' không thể được ghi lại. Sửa GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Đã sửa lỗi khiến một số **phím tắt nút** không hoạt động đúng khi sử dụng bố cục bàn phím không chuẩn.
- Đã sửa lỗi crash trong '**Cài đặt theo ứng dụng**' khi thêm ứng dụng không có 'Bundle ID'. Có thể giúp với GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Đã sửa lỗi crash khi thêm các ứng dụng không có tên vào '**Cài đặt theo ứng dụng**'. Giải quyết GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Cảm ơn đặc biệt tới [jeongtae](https://github.com/jeongtae) đã rất hữu ích trong việc tìm ra vấn đề!
- Thêm nhiều sửa lỗi nhỏ và cải tiến bên trong.