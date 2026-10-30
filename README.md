# FitPlan

Ứng dụng Flutter quản lý hồ sơ, BMI, lịch tập cá nhân, check-in thể trạng, lịch sử tập và gói hội viên. Dữ liệu tài khoản đồng bộ với Supabase; giao diện Việt/Anh, sáng/tối và bố cục responsive.

## Chạy ứng dụng

```powershell
flutter pub get
flutter run -d chrome
```

Hồ sơ thật được yêu cầu sau lần đăng nhập đầu. Project URL và publishable key mặc định dành cho client; có thể thay bằng `--dart-define=SUPABASE_URL=...` và `--dart-define=SUPABASE_ANON_KEY=...`. Khóa service-role và thông tin merchant chỉ đặt trong Supabase Secrets.

## Database và thanh toán

- [Thiết lập Supabase](supabase/README.md)
- [Các migration theo thứ tự](supabase/migrations/)
- [Thiết lập thanh toán](supabase/PAYMENTS_SETUP.md)
- [QR, múi giờ và font](docs/qr_time_typography.md)

Chỉ áp dụng migration còn thiếu. `APPLY_UPGRADE.sql` gộp migration 020000–040000; không chạy lại cả bản gộp lẫn các file riêng. Migration 050000 bật realtime và giờ Việt Nam cho hợp đồng.

Thanh toán cá nhân tại quầy, Vietcombank và MoMo được phòng tập đối chiếu trước khi kích hoạt gói. QR được dựng cục bộ từ mã gốc do chủ app cung cấp, có số tiền và mã đơn. MoMo Business có endpoint xác thực callback riêng.

## Kiểm tra

```powershell
flutter analyze
flutter test
npm --prefix scripts/database ci
npm --prefix scripts/database test
npx --yes deno test supabase/functions/_shared/momo_test.ts
```

Kiểm tra database dùng PostgreSQL chạy cục bộ trong PGlite, không sửa database thật. Kiểm tra Flutter gồm logic check-in, hồ sơ, QR, chuyển tuần và layout với font thật.

## Giữ project gọn

```powershell
flutter clean
flutter pub get
```

`build/`, `.dart_tool/`, `.tmp/`, `node_modules/`, file IDE và khóa cục bộ được loại khỏi Git. Đây là cache/artifact có thể tạo lại; không cần đưa APK hoặc thư mục build lên repository. Sau `flutter clean`, lần chạy đầu cần biên dịch lại.

Font Be Vietnam Pro được đóng gói cùng giấy phép OFL trong `assets/fonts/` và mục giấy phép của ứng dụng.
