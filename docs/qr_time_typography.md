# QR, giờ Việt Nam và typography

- Font Be Vietnam Pro được đóng gói ở `assets/fonts`, đủ 400/500/600/700 và giấy phép OFL. Không gọi Google Fonts khi chạy app.
- Giờ hiển thị theo Việt Nam (UTC+7), đồng hồ cập nhật mỗi giây. Lịch tự chuyển tuần, giữ bản lưu các tuần cũ và không lấy buổi đã qua làm gợi ý tiếp theo.
- QR Vietcombank và MoMo được giải mã từ đúng hai ảnh mới nhất trong Downloads do chủ app chỉ định ngày 30/10/2026. Nội dung tài khoản và dữ liệu định tuyến MoMo giữ nguyên. Khi tạo QR theo đơn, app thêm tag số tiền 54 và nội dung 62/08; tag 62/05 của MoMo được giữ nguyên và checksum được tính lại.
- QR được vẽ trực tiếp bằng `qr_flutter`, không phóng ảnh JPG. Chạm QR hoặc “Phóng to mã QR” mở toàn màn hình, hỗ trợ kéo/zoom đến 4×.
- Thanh toán cá nhân vẫn cần phòng tập đối chiếu tiền. Hiển thị QR không có nghĩa là giao dịch đã thành công.
- Màn hình thanh toán nhận thay đổi trạng thái qua Supabase Realtime và kiểm tra dự phòng mỗi 10 giây. Chạy migration `20261030050000_live_payment_updates.sql` để bật publication và đặt lịch hợp đồng theo múi giờ Việt Nam. Migration này có thể chạy lại và không cần chạy lại `APPLY_UPGRADE.sql`.

Kiểm tra: widget test với font thật, viewport 320px và cỡ chữ 135%, Việt/Anh; kiểm tra QR nguồn và QR có số tiền/nội dung, mở phóng to, chuyển tuần, ranh giới UTC sang ngày Việt Nam. Chạy test sẽ tạo ảnh QA trong `.tmp/review/`; thư mục này không commit và có thể dọn sau khi kiểm tra. QR trong ảnh QA dùng mã đơn kiểm thử; không dùng để thanh toán thật.
