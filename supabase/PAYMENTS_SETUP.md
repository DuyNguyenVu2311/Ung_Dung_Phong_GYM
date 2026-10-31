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

## Nâng cấp vòng đời thanh toán (thành viên 3, 31/10/2026)

Chủ project dev/test triển khai theo thứ tự:

1. Bảo đảm các migration trước đã áp dụng, gồm `20261030050000_live_payment_updates.sql`.
2. Áp dụng **migration mới** `migrations/20261031000000_membership_payment_lifecycle.sql`. Không chạy lại `APPLY_UPGRADE.sql` trên database đã nâng cấp.
3. Deploy lại `membership-payment` cùng các file `_shared`. Giữ `verify_jwt = false` trong `config.toml`: create/status tự xác thực người dùng, IPN xác thực HMAC, cron xác thực service-role bearer.
4. Đặt `MOMO_ENV=test` hoặc `production` rõ ràng. Khi thiếu/sai biến này, chức năng đối soát không gọi gateway. Giữ merchant và môi trường tương ứng cho các đơn đang xử lý; không đổi merchant khi còn đơn chưa đối soát.
5. Cài lịch đối soát bên dưới, thử các ca nghiệm thu trên sandbox, rồi mới phát hành Flutter đã cập nhật. Không bật `online_enabled` cho đến khi merchant hoạt động.

Mã nguồn và test cục bộ không tự cập nhật database, secrets, Edge Function hoặc cron của project chung. Chủ project chịu trách nhiệm các bước triển khai và thử sandbox; phần này chưa được chạy trên merchant thật.

### Nguồn dữ liệu hợp đồng và số buổi

Màn Hội viên và cloud restore cùng gọi `StorageService.refreshMembership`. Truy vấn thành công nhưng không còn hợp đồng hợp lệ sẽ xóa cache và thông báo hết hạn cục bộ của hợp đồng cũ; lỗi truy vấn giữ cache. Hợp đồng inactive/hết hạn không tự chọn chi nhánh hoặc sinh thông báo hết hạn mới. Kết quả trả muộn của tài khoản trước bị bỏ qua.

**Quyết định nghiệp vụ:** Ẩn nhãn “Đã tập” từ `used_sessions` vì hiện chưa có nguồn lượt vào phòng tập được nhân viên/hệ thống xác thực. Các trường cũ giữ nguyên để tương thích dữ liệu. Buổi tập tự ghi, buổi tại nhà và check-in sức khỏe không tăng lượt sử dụng gói. Vì không thực hiện cộng lượt, retry, offline và gia hạn không làm đếm trùng hay tính sai kỳ. Nếu bổ sung lượt gym sau này, cần bảng sự kiện xác thực và RPC chống lặp riêng.

### Trạng thái và phục hồi

- Backend chụp `payment_provider` tại lúc tạo đơn: `manual` hoặc `momo_business`. Tiền mặt, chuyển khoản và MoMo cá nhân vẫn chờ phòng tập đối chiếu, không tự kích hoạt; thay đổi `online_enabled` không đổi luồng đơn đã tạo.
- Đơn online cũ có URL hoặc transaction được xếp Business. Đơn chưa được duyệt, không có URL/transaction được giữ ở `legacy_review` bất kể Business hiện bật hay tắt: trạng thái hiện tại không chứng minh lịch sử đã gọi gateway hay chưa. Client không được hủy, tạo phiên hay hướng dẫn chuyển tiền lại cho các đơn này. IPN/query thành công hợp lệ vẫn tự phục hồi sang Business và kích hoạt đúng một lần; query không tìm thấy đơn không chứng minh khách chưa chuyển khoản cá nhân, nên không tự đóng `legacy_review`.
- Chủ project tra lịch sử merchant và đối chiếu chuyển tiền cá nhân để phân loại đơn `legacy_review`. Bằng backend có service-role, gọi `resolve_legacy_membership_payment(request_id, 'manual')` sau khi xác định đúng là MoMo cá nhân, hoặc `'momo_business'` khi đã xác định là Business. Với manual đã nhận tiền, sau đó gọi `approve_membership_renewal` như quy trình đối chiếu; với Business, gọi status để đối soát. Không phân loại chỉ dựa vào cờ `online_enabled` hoặc tuổi đơn. Không tự bật pending cho đơn cũ đã đóng.
- Business có `payment_expires_at` mặc định 20 phút từ lúc tạo đơn. Đây là hạn để yêu cầu đối soát, **không** tự chứng minh thanh toán thất bại và không phải TTL URL của MoMo. Client ngừng mở URL sau hạn, vẫn cho kiểm tra trạng thái.
- `claim_membership_payment` đánh dấu tạo phiên duy nhất trước khi gửi request. Timeout hoặc lỗi lưu URL vẫn giữ claim; lần sau gọi query, không tạo phiên khác. Đơn chưa từng gửi có thể hủy ngay. Đơn đã gửi chỉ đóng bằng kết quả gateway hợp lệ.
- `POST membership-payment` với `{ "request_id": "UUID", "action": "status" }` xác thực chủ đơn rồi gọi `/v2/gateway/api/query`. `action=create` tạo phiên lần đầu; nếu đã thử tạo thì cũng đối soát.
- Kết quả `0` kèm đúng merchant/order/request/amount và transaction hợp lệ mới kích hoạt. IPN vẫn kiểm tra HMAC. Query là HTTPS server-to-server theo giao thức MoMo, tài liệu query không khai báo chữ ký phản hồi; không dùng dữ liệu redirect/client để xác nhận.
- Các mã chờ `1000`, `7000`, `7002`, `9000`, lỗi hệ thống/credentials, mã lạ và mất mạng không đóng đơn. Với Business đã xác định, mã giao dịch thất bại đã biết mới chuyển `rejected`; `1005` chuyển `expired`. Query trả `42` chỉ được đóng sau hạn cộng 5 phút, với đúng merchant/order/query request. Trước đó giữ pending để tránh tranh chấp request tạo còn đang xử lý. `legacy_review` cần thành công xác thực hoặc phòng tập phân loại như trên.
- `apply_momo_result` khóa đơn và áp dụng kết quả trong cùng transaction với hợp đồng/thông báo. Callback/query lặp chỉ kích hoạt một lần; thất bại đến sau thành công không hạ trạng thái. Thành công xác thực đến muộn có thể phục hồi đơn đã đóng, kể cả khi khách đang có đơn khác pending. Transaction đã dùng cho đơn khác hoặc số tiền sai bị từ chối.
- `cancelled`, `expired`, `rejected` giải phóng chỗ pending để đăng ký lại. Nếu kết quả vẫn chưa chắc chắn, giữ đơn và hướng dẫn khách liên hệ phòng tập; không bảo khách chuyển tiền lần nữa. Lịch sử cho phép kiểm tra lại cả đơn Business đã đóng.

Tham chiếu giao thức: [API query](https://developers.momo.vn/v3/vi/docs/payment/api/payment-api/query/) quy định chữ ký `accessKey`, `orderId`, `partnerCode`; [mã kết quả](https://developers.momo.vn/v3/vi/docs/payment/api/result-handling/resultcode/) phân biệt lỗi request và kết quả cuối của giao dịch.

### Lịch đối soát khi người dùng đóng ứng dụng

Chủ project cấu hình Supabase Cron hoặc scheduler backend gọi mỗi phút:

```text
POST https://YOUR_PROJECT.supabase.co/functions/v1/membership-payment/reconcile
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY lấy từ kho secrets của scheduler>
Content-Type: application/json
Body: {}
```

Không đưa khóa vào Flutter, Git, log hoặc ảnh chụp. Endpoint chỉ nhận bearer service-role của backend; token hội viên không có quyền. Mỗi lượt đối soát tối đa 10 đơn song song, mỗi HTTP gateway timeout 35 giây; có thể gọi lại sau khi lượt trước kết thúc. Đơn được khóa khi ghi kết quả nên overlap/IPN không cộng hợp đồng hai lần. Đơn pending quá hạn được xử lý kể cả khi cũ; đơn Business đã đóng có lần gửi gateway được kiểm tra lại trong 7 ngày để phục hồi thành công muộn. IPN và kiểm tra thủ công của chủ đơn vẫn nhận thành công sau khoảng này. Thứ tự `gateway_checked_at` ưu tiên đơn lâu chưa được thử, kể cả sau lỗi HTTP, để tránh một batch lỗi chặn các đơn phía sau.

Phản hồi `{ "checked": N, "failed": N }` phản ánh lượt đối soát; scheduler cần ghi số lượng và cảnh báo khi lỗi kéo dài. Không đóng pending chỉ vì cron lỗi hoặc MoMo trả mã không rõ. Nếu chưa cài job, nút kiểm tra trạng thái vẫn hoạt động nhưng đơn bỏ dở không tự đối soát khi ứng dụng đóng.

### Kiểm tra nâng cấp

```powershell
flutter analyze --no-pub
flutter test --no-pub
npm --prefix scripts/database ci
npm --prefix scripts/database test
node scripts/database/check.mjs
npx --yes deno test --allow-env supabase/functions/_shared supabase/functions/membership-payment/index_test.ts
npx --yes deno check supabase/functions/membership-payment/index.ts
```

Test dùng PGlite và HTTP gateway giả lập; không liên hệ Supabase/MoMo thật và không thay thế nghiệm thu sandbox. Trên Windows chưa bật Developer Mode, `pub get` có thể báo thiếu symlink sau khi tải dependencies; unit/widget test dùng `--no-pub` nếu `.dart_tool/package_config.json` đã được tạo. Không hạ SDK constraint để né yêu cầu Dart.
