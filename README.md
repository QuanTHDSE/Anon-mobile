# AnonWork Mobile

Ứng dụng di động (Flutter) của **AnonWork** — mạng xã hội cho phép đăng bài ẩn danh.
App được port từ web client (`EXE101`, React + TypeScript) và dùng **chung API production**:
`https://api.anonwork.site` (media/CDN: `https://cdn.anonwork.site`).

---

## Tính năng

- **Xác thực**: đăng nhập, đăng ký, quên mật khẩu (2 bước: gửi mã → đặt lại), tự động làm mới token khi hết hạn (refresh 401).
- **Feed**: danh sách bài viết, tìm kiếm (debounce), cuộn vô hạn, upvote, bookmark, hiển thị ảnh ẩn danh.
- **Chi tiết bài viết**: ảnh, tệp đính kèm, upvote và **bình luận** (ẩn danh, trả lời, xóa bình luận của mình).
- **Tạo bài viết**: chọn chuyên ngành, tags, đăng ẩn danh. Áp giới hạn theo gói (Free: 1 ảnh/bài, không đính kèm tệp).
- **Hồ sơ**: thống kê bài/follower/following, chỉnh sửa hồ sơ (avatar, bio, tên ẩn danh, ẩn danh mặc định) và **chọn ảnh đại diện ẩn danh** (ảnh độc quyền `isExclusive` bị khóa với tài khoản Free).
- **Đã lưu / Kết nối / Bảng xếp hạng**: bookmarks, following & followers, top bài viết.
- **Premium**: danh sách gói cước và thanh toán qua **SePay** (mã QR + thông tin chuyển khoản + tự kiểm tra trạng thái).

---

## Yêu cầu

- **Flutter SDK** với Dart `>= 3.11.5` (chạy `flutter --version` để kiểm tra).
- Thiết bị/emulator Android hoặc iOS (hoặc trình duyệt cho web build).

## Cài đặt & chạy

```bash
cd anon_mobile
flutter pub get
flutter run
```

Các lệnh hữu ích:

```bash
flutter analyze     # kiểm tra tĩnh
flutter test        # chạy widget test
flutter build apk   # đóng gói Android
```

> App gọi thẳng API production nên **cần kết nối Internet**. Bản Android đã khai báo
> quyền `INTERNET` trong `android/app/src/main/AndroidManifest.xml`.

---

## Cấu hình

Các hằng số cấu hình nằm trong [`lib/core/config.dart`](lib/core/config.dart):

| Hằng số | Giá trị | Ý nghĩa |
|---|---|---|
| `apiBaseUrl` | `https://api.anonwork.site` | Base URL của API (giống web) |
| `cdnBaseUrl` | `https://cdn.anonwork.site` | CDN/R2 phục vụ ảnh & tệp |
| `brandColorValue` | `#F15B29` | Màu thương hiệu |

Đổi API sang môi trường khác bằng cách sửa `apiBaseUrl` (và `cdnBaseUrl`) tại đây.

---

## Kiến trúc

State quản lý bằng [`provider`](https://pub.dev/packages/provider). Mỗi service là singleton
gọi qua `ApiClient` chung (Bearer token, tự refresh khi 401, bóc tách lỗi ASP.NET Core, giải mã UTF-8).

```
lib/
├── main.dart                 # Khởi tạo, AuthGate (đăng nhập ↔ HomeShell)
├── core/
│   ├── config.dart           # URL API/CDN, màu brand, toAbsoluteMediaUrl()
│   ├── api_client.dart       # HTTP client: token, refresh, multipart, lỗi
│   └── theme.dart            # ThemeData + bảng màu (AppColors)
├── models/                   # user, post, comment, anon_image, subscription
│   └── ...                   # parse JSON "khoan dung" như bên web
├── services/                 # 1 file / domain, ánh xạ endpoint của web
│   ├── auth_service.dart         # /auth/login|register|forgot|reset|refresh
│   ├── user_service.dart         # /users/me, /users/{id}
│   ├── post_service.dart         # /posts, /posts/top, upvote, create/update
│   ├── comment_service.dart      # /comments/post/{id}, tạo/xóa/upvote
│   ├── bookmark_service.dart     # /bookmarks
│   ├── follow_service.dart       # /follows (stats, followers, following)
│   ├── anon_image_service.dart   # /anon-images, gán ảnh ẩn danh
│   └── subscription_service.dart # /subscription-plans, /payments (SePay)
├── state/
│   └── auth_state.dart       # ChangeNotifier: user, profile (getMe), isPremium
├── widgets/
│   ├── app_logo.dart         # Logo SVG dùng chung (assets/logo.svg)
│   ├── author_avatar.dart    # Avatar anon-aware (ảnh → icon ẩn danh → chữ cái)
│   └── post_card.dart        # Thẻ bài viết trong feed
└── screens/                  # Các màn hình (feed, chi tiết, tạo bài, hồ sơ, ...)
```

**Luồng dữ liệu**: `Screen` → `Service` → `ApiClient` → API. `AuthState` giữ phiên đăng nhập
và trạng thái Premium, được `provider` phát cho toàn app.

---

## Ghi chú

- Logo (`assets/logo.svg`) đồng bộ với logo web, render bằng [`flutter_svg`](https://pub.dev/packages/flutter_svg).
- Giới hạn Free/Premium được **enforce ở server**; app chỉ phản chiếu để UX rõ ràng
  (ẩn nút, hiện gợi ý nâng cấp).

### Chưa có (so với web)

- Sửa bài viết & đính kèm tệp khi đăng.
- Trang hồ sơ người dùng khác, đăng nhập Google, và trang quản trị (admin).
