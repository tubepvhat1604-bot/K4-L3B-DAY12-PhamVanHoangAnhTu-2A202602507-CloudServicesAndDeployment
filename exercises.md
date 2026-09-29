# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Văn Hoàng Anh Tú  Mã học viên: 2A202602507

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy lên Railway, nếu em quên set `AGENT_API_KEY` trong tab Variables thì container vừa khởi động đã báo `ValidationError: agent_api_key Field required`, deploy đỏ ngay, health check không qua, em thấy lỗi và sửa trong vài phút. Nếu để mặc định `"changeme"` thì service vẫn lên xanh, `/ask` vẫn trả lời, và bất kỳ ai gửi header `X-API-Key: changeme` (chuỗi này nằm công khai trong repo) đều dùng agent bằng tiền của em mà em không hề biết, cho tới khi nhìn hóa đơn cuối tháng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T02:40:13.477541+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 41, "cost_usd": 2.505e-05}
```

1. Lọc và cộng theo trường: lọc `event = ask_completed`, nhóm theo `user_id` rồi cộng `cost_usd` để biết user nào tiêu nhiều tiền nhất, hoặc cộng `tokens_in`/`tokens_out` để theo dõi lượng token. Dòng `print` chỉ là một câu chữ, không có trường nào để lọc hay cộng.
2. Lọc theo `level` và đặt cảnh báo: platform log đọc được khóa `level`, nên có thể đặt cảnh báo khi số dòng `error` trong 5 phút vượt ngưỡng, hoặc vẽ biểu đồ số request theo `timestamp`. Dòng `print` không có thời gian, mức độ hay user nên không làm được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f Dockerfile.single -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần chênh lệch chủ yếu đến từ base image: Bản multi-stage nhỏ hơn khoảng 6,4 lần, chênh lệch gần 1,46 GB.`python:3.11` bản đầy đủ dựa trên Debian đầy đủ, mang theo trình biên dịch gcc, header C, git, các thư viện phát triển và tài liệu, còn `python:3.11-slim` chỉ giữ phần tối thiểu để chạy Python. Bản 1 stage còn `COPY . .` nên mang theo cả `tests/`, tài liệu và cache pip. Bản multi-stage chỉ copy thư mục `/install` (thư viện đã cài) từ stage builder sang, cộng với `app/` và `utils/`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Toàn bộ stage builder (`COPY requirements.txt`, `RUN pip install`) được dùng lại từ cache vì `requirements.txt` không đổi. Ở stage runtime, các layer `COPY --from=builder` và `RUN useradd` cũng lấy từ cache. Chỉ layer `COPY app ./app` và các layer sau nó (`COPY utils`, `USER`, `HEALTHCHECK`, `CMD`, đều chạy gần như tức thì) phải làm lại, nên build xong trong vài giây.

Nếu đặt `COPY . .` trước `pip install` thì sửa một ký tự trong code cũng làm layer `COPY . .` đổi checksum, Docker hủy cache từ đó trở đi, và `pip install` phải tải, cài lại toàn bộ thư viện mỗi lần build, mất vài phút thay vì vài giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

1. Code có lỗ hổng (ví dụ thư viện lỗi deserialize, hoặc chỗ gọi lệnh shell từ input người dùng) cho phép kẻ tấn công chạy lệnh tùy ý trong process.
2. Process đang chạy bằng root (UID 0) nên kẻ tấn công có ngay quyền root trong container: đọc mọi file, cài công cụ, sửa code app.
3. UID 0 trong container cũng là UID 0 trên kernel của host. Nếu container có mount volume từ host, có socket Docker, hoặc kernel có lỗ hổng escape, kẻ tấn công dùng quyền root đó để thoát ra và thành root trên máy host.

Lệnh `USER agent` cắt chuỗi ở bước 2: kẻ tấn công chỉ có quyền của user UID 10001, không cài được gói, không sửa được file hệ thống, và nếu có thoát ra host thì cũng chỉ là một user thường, muốn leo lên root khó hơn rất nhiều.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa **20 request** trong khoảng 2 giây. Cách làm: gửi 10 request lúc 10:00:59, đúng hạn mức của phút 10:00. Sang 10:01:00 bộ đếm reset về 0, gửi tiếp 10 request nữa, đúng hạn mức của phút 10:01. Mỗi phút đồng hồ đều "đúng luật" nhưng thực tế 20 request dồn vào khoảng 1–2 giây, gấp đôi hạn mức.

Với sliding window, lúc 10:01:00 hàm `hit_count` đếm các request trong 60 giây tính ngược từ thời điểm hiện tại, nên vẫn thấy 10 request của giây 59 và trả 429 ngay. Trong bất kỳ khoảng 60 giây nào cũng không bao giờ quá 10 request.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit đếm **số lượng request** trong 60 giây gần nhất, bảo vệ service khỏi bị gọi dồn dập (bot, vòng lặp lỗi). Cost guard cộng **số tiền** đã tiêu trong tháng, bảo vệ ngân sách, không quan tâm gọi nhanh hay chậm.

- Rate limit cho qua, cost guard chặn: một user gửi đều đặn 5 câu mỗi phút (dưới hạn mức 10), nhưng mỗi câu kèm lịch sử dài và văn bản lớn, tốn rất nhiều token. Không lần nào bị 429, nhưng tiền cộng dồn tới $10 giữa tháng thì cost guard trả 402.
- Cost guard cho qua, rate limit chặn: một script lỗi gửi 15 câu ngắn trong 5 giây. Mỗi câu chỉ tốn vài phần triệu đô, ngân sách còn gần như nguyên, nhưng từ request thứ 11 bị 429 vì vượt 10 request/phút.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis mất kết nối.
2. Cả 3 container gọi health check, cả 3 đều ping Redis thất bại nên cùng trả 503.
3. Orchestrator dùng endpoint này làm liveness nên hiểu là "process hỏng", sau vài lần fail liên tiếp nó **restart cả 3 container cùng lúc**.
4. Trong lúc restart không còn container nào nhận request, người dùng bị lỗi 502/503 hoàn toàn.
5. Redis quay lại sau 30 giây, nhưng các container vẫn đang khởi động lại, hoặc khởi động xong mà Redis chưa ổn lại bị restart tiếp. Sự cố 30 giây của Redis thành sự cố sập toàn hệ thống lâu hơn nhiều.

Khi tách ra: `/health` vẫn 200 nên không container nào bị restart, chỉ `/ready` trả 503 nên load balancer tạm ngừng gửi traffic. Redis quay lại thì `/ready` 200 ngay và traffic chảy lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Với Redis, `history_length` tăng đều 0, 2, 4, 6... qua mỗi lần gọi (mỗi lượt ghi thêm 2 message user + assistant), dù request rơi vào container nào, vì cả 3 container đọc và ghi cùng một key `history:<user_id>` trong Redis.

Nếu lưu trong dict Python, mỗi container có dict riêng trong RAM của nó. Nginx chia request lần lượt cho 3 container, nên con số sẽ nhảy lộn xộn kiểu 0, 0, 0, 2, 2, 2, 4...: mỗi container chỉ nhớ những lượt mà chính nó xử lý. Agent trông như "mất trí nhớ" ngẫu nhiên, và khi một container restart thì phần lịch sử của nó mất hẳn, quay về 0.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> *Câu trả lời của bạn*
