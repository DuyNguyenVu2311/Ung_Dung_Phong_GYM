# FitPlan: cấu hình hồ sơ và thanh toán thật

Chạy các migration mới theo thứ tự:

1. `20261030020000_real_member_flows.sql`
2. `20261030030000_payment_methods.sql`
3. `20261030040000_gym_packages.sql`

Hoặc chạy một lần toàn bộ `APPLY_UPGRADE.sql` trong SQL Editor (file đã gộp ba migration trên thành một transaction). Không chạy lại ba migration riêng nếu đã chạy file gộp.

Migration 020000 ngừng kích hoạt hợp đồng mẫu `FIT-YYYYMM-001` và xóa buổi bootstrap `s1` có đúng một log Bench Press 4×8×60 của hồ sơ chưa hoàn tất. Dữ liệu khác giữ nguyên.

Migration 040000 tạo gói thật do chủ app cung cấp: 1 tháng 299.000đ và 3 tháng 807.300đ (giảm 10% so với ba tháng lẻ), tại Thủ Đức, Bình Thạnh, Quận 1. Hạn gói được cộng theo tháng lịch bằng `duration_months`; `duration_days` chỉ là số ngày tương đương dự phòng. Chưa thêm địa chỉ đường phố vì chủ app chưa cung cấp.

`payment_settings` đã có thông tin chủ app cung cấp: Vietcombank, Nguyễn Vũ Duy, STK 1042362758, MoMo 0775571311. Người dùng đã đăng nhập được đọc các thông tin nhận tiền này; chỉ quản trị viên thay đổi chúng.

## Thanh toán tại quầy và chuyển khoản

Khách chọn gói và phương thức. Backend chụp giá, số ngày và chi nhánh tại thời điểm tạo yêu cầu; client không tự thay số tiền hoặc tự kích hoạt hợp đồng. Yêu cầu nằm ở `membership_renewal_requests`.

Phòng tập đối chiếu khoản tiền đã nhận trước khi gọi `approve_membership_renewal(request_id)` bằng backend có service-role. Trong SQL Editor của chủ dự án có thể thực hiện:

```sql
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.approve_membership_renewal('UUID_CUA_YEU_CAU'::uuid);
commit;
```

Chỉ chạy sau khi thực sự nhận tiền. Function cập nhật hợp đồng, trạng thái yêu cầu và thông báo trong cùng một giao dịch. Không dùng service-role trong Flutter.

## MoMo cá nhân

Khi `online_enabled = false`, phương thức MoMo hiện số người nhận, số tiền và nội dung chuyển tiền; phòng tập đối chiếu, xác nhận như chuyển khoản ngân hàng. Số điện thoại cá nhân chưa đủ để sử dụng API thanh toán tự động.

## MoMo Business: tự động xác nhận

Đăng ký merchant tại MoMo Business để được cấp `partnerCode`, `accessKey`, `secretKey`. Đặt trong **Supabase > Edge Functions > Secrets**:

- `MOMO_PARTNER_CODE`
- `MOMO_ACCESS_KEY`
- `MOMO_SECRET_KEY`
- `MOMO_ENV=production` (dùng `test` khi kiểm thử merchant sandbox)

Deploy `supabase/functions/membership-payment/index.ts` với `verify_jwt = false` như `config.toml`. API tạo phiên tự kiểm tra bearer token và chủ sở hữu yêu cầu; callback IPN kiểm tra HMAC-SHA256, merchant, mã đơn, số tiền và mã giao dịch. Trình duyệt quay lại không tự kích hoạt gói tập.

IPN URL:

```text
https://cdbxmtodyvdmiddcccag.supabase.co/functions/v1/membership-payment/ipn
```

Redirect URL:

```text
https://cdbxmtodyvdmiddcccag.supabase.co/functions/v1/membership-payment/return
```

Các URL được backend gửi kèm mỗi yêu cầu `captureWallet`. Sau khi deploy và thử giao dịch, bật `payment_settings.online_enabled = true` để chuyển từ MoMo đối chiếu thủ công sang cổng MoMo Business. App mở trang MoMo, khách quay lại và bấm “Kiểm tra trạng thái”.

Chưa có merchant nên chưa thể kiểm thử giao dịch tiền thật. Test chữ ký và kiểm tra đơn bằng:

```powershell
npx --yes deno test supabase/functions/_shared/momo_test.ts
```

Tài liệu MoMo chính thức: https://developers.momo.vn/v3/vi/docs/payment/api/wallet/onetime/ và https://developers.momo.vn/v3/vi/docs/payment/api/result-handling/notification/.
