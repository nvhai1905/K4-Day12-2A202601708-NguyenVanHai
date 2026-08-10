# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng trích dẫn in nghiêng bên dưới mỗi câu bằng nội dung
> của mình. `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Văn Hải  Mã học viên: 2A202601708

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống: mình deploy lên Railway lúc 5h chiều, tạo service xong nhưng quên
> bấm thêm biến `API_TOKEN` vào tab Variables.
>
> **Nếu có mặc định `"changeme"`:** service khởi động bình thường, `/healthz`
> xanh, dashboard báo Deployed. Mình yên tâm tắt máy đi về. Nhưng lúc này bất
> kỳ ai đọc repo public của mình trên GitHub đều thấy dòng
> `api_token: str = "changeme"`, và họ gọi được `/chat` bằng đúng token đó.
> Rate limit tính theo `X-Client-Id` do client tự khai, nên họ chỉ cần đổi
> header là có xô token mới. Mình chỉ phát hiện khi nhìn hóa đơn hoặc khi thấy
> `spend:*` trong Redis phình bất thường — có thể là vài ngày sau.
>
> **Vì không có mặc định:** ngay giây đầu tiên, `Settings()` ném
> `ValidationError: api_token Field required`, uvicorn in
> `Application startup failed. Exiting.` và container chết. Dashboard hiện
> Crashed màu đỏ. Mình thấy ngay trên màn hình khi còn đang deploy, mở
> Variables thêm biến, deploy lại — mất 30 giây.
>
> Điểm mấu chốt: lỗi cấu hình là thứ **luôn** xảy ra. Câu hỏi không phải "có
> quên không" mà là "quên thì biết lúc nào". Mặc định cho secret biến một lỗi
> ồn ào 30 giây thành một lỗ hổng im lặng nhiều ngày. Mình đã gặp đúng dạng
> "lỗi im lặng" này khi chạy `uvicorn` lần đầu: app chết lúc startup vì
> `lifecycle.arm()` chưa cài, nhưng `pytest` vẫn xanh 13/13 — test không kích
> hoạt lifespan nên không chạm vào đường đó.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy từ `docker compose logs chat`:
>
> ```json
> {"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T09:02:12.561550+00:00", "client_id": "sv01", "prompt_tokens": 126, "completion_tokens": 47, "usd_cost": 4.71e-05}
> ```
>
> **Việc 1 — Truy ra ai đang đốt tiền, không cần đọc bằng mắt.** Vì `client_id`
> và `usd_cost` là hai trường riêng biệt chứ không phải chữ lẫn trong câu, mình
> gom nhóm theo `client_id` rồi cộng `usd_cost` là ra bảng xếp hạng chi tiêu
> trong ngày. Với `print("đã trả lời xong")` thì thông tin đó không tồn tại;
> mà kể cả có in ra dạng câu chữ thì phải viết regex bóc tách, và regex vỡ ngay
> khi ai đó sửa lời văn của câu log.
>
> **Việc 2 — Đặt cảnh báo tự động theo mức độ.** Trường `severity` viết hoa là
> quy ước mà Google Cloud Logging / Datadog hiểu được, nên mình đặt được luật
> kiểu "nếu số dòng `severity=ERROR` trong 5 phút vượt 10 thì bắn cảnh báo".
> `print()` không có khái niệm mức độ — mọi dòng đều như nhau, không lọc được,
> không đếm được, không cảnh báo được.
>
> Thêm một điểm mình quan sát được khi chạy 3 container: log của cả 3 đổ chung
> vào một luồng, nhưng vì mỗi dòng là một JSON độc lập nên vẫn tách được theo
> `client_id` và `ts`. Nếu log xuống dòng (dùng `indent=2`) thì các container
> ghi xen kẽ nhau và toàn bộ nhật ký thành rác không parse nổi.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | **1730 MB** (1.73 GB) |
| Multi-stage | **270 MB** |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch **1460 MB, tức là image nhỏ đi 6.4 lần**. Phần bị cắt gồm ba nhóm:
>
> **1. Base image (chiếm phần lớn).** Bản đầu dùng `python:3.11` đầy đủ (~1 GB),
> bản mới dùng `python:3.11-slim` (~130 MB). Bản đầy đủ kèm bộ biên dịch GCC,
> header của hàng chục thư viện C, tài liệu, locale, các công cụ dev như git và
> curl. Runtime chỉ cần thông dịch Python và vài thư viện — không dùng đến một
> dòng nào trong số đó.
>
> **2. Vết tích của quá trình cài đặt.** Ở bản 1 stage, mọi thứ `pip` tạo ra
> trong lúc cài đều nằm lại trong layer: cache tải về, file `.tar.gz` nguồn,
> thư mục build tạm. Ở bản multi-stage những thứ này sinh ra ở stage `builder`
> rồi **bị vứt cùng cả stage đó** — chỉ có thư mục `/install` (kết quả cuối)
> được `COPY --from=builder` sang.
>
> **3. Rác từ build context.** Bản đầu dùng `COPY . .` nên bê nguyên `.git`,
> `.venv`, `__pycache__`, `tests/`, `screenshots/` vào image. Bản mới chỉ
> `COPY app ./app` và `COPY utils ./utils`, cộng thêm `.dockerignore` chặn sẵn.
> Mình kiểm chứng bằng `docker compose exec chat ls -a /app` — bên trong chỉ có
> `app` và `utils`, không có `.env`.
>
> Ý nghĩa thực tế: 1.73 GB nghĩa là mỗi lần deploy phải đẩy/kéo ngần ấy dữ liệu
> qua mạng. Với free tier của Railway/Render thì đó là khác biệt giữa deploy 30
> giây và deploy 5 phút, nhân với số lần deploy trong ngày.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình chạy thí nghiệm thật: thêm một dòng comment vào `app/main.py` rồi
> `docker build` lại, đo bằng `date` và đọc cờ `CACHED` trong log build.
>
> **Với Dockerfile multi-stage của mình — build hết 0.8 giây:**
>
> | Layer | Kết quả |
> |---|---|
> | `FROM python:3.11-slim AS builder` | CACHED |
> | `COPY requirements.txt .` | CACHED |
> | `RUN pip install --prefix=/install` | **CACHED** ← đắt nhất, giữ được |
> | `COPY --from=builder /install /usr/local` | CACHED |
> | `COPY app ./app` | chạy lại |
> | `COPY utils ./utils` | chạy lại |
> | `RUN useradd ... && chown -R /app` | chạy lại |
>
> **Với bản `COPY . .` đứng trước `pip install` — build hết 27.4 giây:**
> log ghi rõ `pip install` **không** CACHED, phải cài lại toàn bộ 13 thư viện
> trong `requirements.txt` từ đầu.
>
> **Chênh lệch: 0.8 giây so với 27.4 giây — chậm hơn 34 lần**, chỉ vì đổi thứ
> tự hai dòng lệnh.
>
> Nguyên nhân: Docker cache theo từng layer và **hủy cache từ layer đầu tiên
> thay đổi trở đi**, không hủy chọn lọc. `COPY . .` gộp cả code lẫn
> `requirements.txt` vào một layer, nên sửa bất cứ ký tự nào trong repo cũng
> làm layer đó đổi hash → mọi layer sau nó, kể cả `pip install`, bị coi là mới.
> Tách `COPY requirements.txt` riêng thì layer đó chỉ đổi khi danh sách thư viện
> thực sự đổi — chuyện hiếm khi xảy ra.
>
> Nguyên tắc rút ra: **xếp lệnh theo tần suất thay đổi, ít đổi lên trên, hay đổi
> xuống dưới.** Đây cũng là lý do `RUN useradd` bị chạy lại trong bảng trên —
> mình đặt nó sau `COPY app`, đúng ra có thể đưa lên trước để tiết kiệm thêm,
> nhưng nó chỉ tốn 0.1 giây nên không đáng đánh đổi với việc `chown` phải chạy
> sau khi code đã nằm đúng chỗ.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> **Chuỗi sự kiện khi container chạy bằng root:**
>
> 1. **Lỗ hổng trong code.** Ví dụ một endpoint nhận tên file từ người dùng rồi
>    mở nó mà không kiểm tra, hoặc một thư viện phụ thuộc dính lỗi
>    deserialization. Kẻ tấn công gửi payload và chạy được lệnh tùy ý bên trong
>    container.
> 2. **Toàn quyền bên trong container.** Vì tiến trình là root (uid 0), nó ghi
>    được vào mọi thư mục, cài thêm công cụ, đọc mọi biến môi trường — bao gồm
>    `API_TOKEN` và `REDIS_URL` kèm mật khẩu.
> 3. **Dò đường thoát ra host.** Đây là bước quyết định. Container chỉ là tiến
>    trình Linux bị giới hạn bằng namespace và cgroup, không phải máy ảo. Root
>    trong container có sẵn các capability như `CAP_DAC_OVERRIDE`, và **uid 0
>    trong container chính là uid 0 trên host** (trừ khi bật user namespace
>    remapping, mặc định thì không). Nên nếu có bất cứ đường rò nào — socket
>    `/var/run/docker.sock` bị mount nhầm, một volume mount ghi được, hoặc một
>    lỗi kernel/runtime chưa vá — thì root trong container thành root trên host.
> 4. **Toàn quyền máy chủ.** Đọc được container khác, lấy secret của cả cụm.
>
> **`USER appuser` cắt chuỗi ở bước 2 → 3.** Sau lệnh đó tiến trình chạy bằng
> uid 10001, không có capability đặc quyền nào. Kẻ tấn công vẫn chiếm được ứng
> dụng (bước 1–2 vẫn xảy ra), nhưng:
> - Không ghi được vào `/usr`, `/etc`, không cài thêm gói
> - Nếu có volume mount thì cũng chỉ ghi được nơi uid 10001 có quyền
> - Kể cả thoát được ra host thì cũng chỉ là một user vô danh uid 10001, không
>   sở hữu file nào của hệ thống
>
> Nói cách khác, `USER` không ngăn được việc bị chiếm ứng dụng — nó **giới hạn
> thiệt hại tối đa** của việc đó. Đây là nguyên tắc least privilege: cho đúng
> quyền tối thiểu cần thiết, vì ứng dụng này chỉ cần đọc code và nói chuyện với
> Redis, không cần quyền gì hơn.
>
> Mình kiểm chứng bằng `docker compose exec chat id` → `uid=10001(appuser)`.
> Lưu ý khi viết: phải `chown -R appuser /app` **trước** `USER`, nếu không user
> thường không có quyền đọc code và container chết ngay lúc khởi động.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> **Về `WWW-Authenticate: Bearer`** — đây là yêu cầu của chuẩn HTTP (RFC 7235).
> Mã 401 nghĩa là "chưa xác thực", và server có nghĩa vụ nói tiếp **phải xác
> thực bằng cách nào**, vì có nhiều kiểu: Basic, Digest, Bearer, Negotiate.
> Thiếu header này thì client chỉ biết "bị từ chối" mà không biết cần gửi gì.
>
> Giá trị thực tế: các thư viện HTTP tự động đọc header này để chọn cơ chế xác
> thực và thử lại; trình duyệt dùng nó để quyết định có bật hộp thoại đăng nhập
> hay không; và về mặt ngữ nghĩa, 401 **không có** `WWW-Authenticate` thì đúng
> ra phải là 403 (đã biết bạn là ai, nhưng không cho phép). Hai mã này khác
> nhau: 401 = "thử lại với thông tin xác thực", 403 = "thử lại cũng vô ích".
>
> Mình kiểm chứng bằng `curl -i`:
> ```
> HTTP/1.1 401 Unauthorized
> www-authenticate: Bearer
> ```
>
> **Về việc dùng chung một thông báo** — đây là đánh đổi có chủ đích giữa *tiện
> cho người dùng thật* và *khó cho kẻ tấn công*, và ở endpoint xác thực thì vế
> sau thắng.
>
> Lý do: mỗi thông báo lỗi khác nhau là một **oracle** — một cỗ máy trả lời
> đúng/sai cho kẻ đang dò. Nếu server phân biệt "sai scheme" với "token không
> đúng", kẻ tấn công biết ngay định dạng token của mình đã đúng và chỉ cần dò
> giá trị. Nếu phân biệt tiếp "token không tồn tại" với "token đã hết hạn", nó
> biết được token nào **từng tồn tại** — thu hẹp không gian tìm kiếm rất nhiều.
>
> Đây cùng một họ vấn đề với `secrets.compare_digest`: cả thời gian phản hồi lẫn
> nội dung thông báo đều là kênh rò rỉ thông tin. Chống một cái mà để hở cái kia
> thì vô nghĩa.
>
> Còn người dùng thật thì sao? Họ không bị thiệt mấy, vì với API thì tài liệu
> mới là nơi hướng dẫn cách gắn token, không phải thông báo lỗi. Và với đúng một
> cách xác thực duy nhất thì "sai ở đâu" cũng chỉ có vài khả năng, tự thử là ra.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Mình chạy thử bằng chính lớp `TokenBucket` với `fakeredis`, truyền tham số
> `now` để tua thời gian (xô cạn tại t=1000, rồi bắn tiếp tại t=1600):
>
> | Trường hợp | Số request qua được |
> |---|---|
> | Có `min(capacity, ...)` | **10** rồi 429 |
> | Bỏ `min(capacity, ...)` | **100** rồi 429 |
> | Bỏ `min()`, im lặng 24 giờ | **14.400** |
>
> **Vì sao có `min()` là 10:** trong 600 giây xô nhỏ thêm
> `600 × (10/60) = 100` token, nhưng `min(10, 100)` cắt xuống còn 10 — đúng
> bằng sức chứa. Xô là cái xô, đầy thì tràn ra ngoài.
>
> **Vì sao bỏ `min()` là 100:** không còn chặn trên, con số 100 token đó được
> giữ nguyên. Client bắn 100 phát liên tiếp mới bị chặn — **gấp 10 lần hạn mức
> mình khai báo**. Tệ hơn nữa, con số này tỉ lệ thuận với thời gian im lặng: 24
> giờ không gọi thì tích được 14.400 token và bắn hết trong vài giây.
>
> Ý nghĩa: bỏ một dòng `min()` không làm rate limit *sai lệch chút ít*, mà làm
> nó **mất tác dụng đúng vào lúc cần nhất**. Đợt tấn công điển hình là im lặng
> rồi bùng nổ, chứ không ai gọi đều đặn để bị chặn.
>
> Điều này cũng cho thấy `capacity` và `refill_per_minute` là hai tham số điều
> chỉnh hai thứ khác nhau: `refill` quyết định **tốc độ trung bình dài hạn**
> (10 request/phút), còn `capacity` quyết định **độ bùng nổ tối đa cho phép**
> (tối đa 10 phát liên tiếp). Muốn cho phép bấm dồn nhiều hơn thì tăng
> `capacity`, muốn cho gọi nhiều hơn về lâu dài thì tăng `refill` — đó chính là
> điểm mạnh của token bucket so với bộ đếm cứng "N request mỗi phút".

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Hai cách có **cùng tổng ngân sách $30/tháng**, nhưng hành vi khi có sự cố thì
> khác hẳn.
>
> | | Hạn mức $30/tháng | Hạn mức $1/ngày |
> |---|---|---|
> | Thiệt hại tối đa của một sự cố | **$30** (cả tháng) | **$1** |
> | Chặn lúc nào | Khi đã tiêu hết $30 | Sau khoảng vài phút |
> | Service hồi phục khi nào | **Đầu tháng sau**, hoặc phải có người vào nâng hạn mức bằng tay | **00:00 UTC hôm sau, tự động** |
> | Ai chịu hậu quả sau đó | Mọi request hợp lệ còn lại trong tháng đều bị chặn | Chỉ các request còn lại trong ngày hôm đó |
>
> **Diễn biến với $30/tháng:** sự cố bắt đầu 2h sáng ngày 5. Client gọi liên
> tục, tiêu hết $30 trước khi trời sáng. 8h sáng mình mở máy thì thấy service
> đã chặn **toàn bộ** client suốt 25 ngày còn lại của tháng. Mình mất $30 và
> phải can thiệp thủ công để service dùng lại được.
>
> **Diễn biến với $1/ngày:** cùng sự cố, cùng 2h sáng. Client tiêu hết $1 trong
> vài phút rồi nhận 402. Đến 8h sáng mình thấy log có 402 và điều tra. Thiệt hại
> $1. Và kể cả mình không làm gì cả, 00:00 UTC hôm sau key
> `spend:<client>:<ngày>` mới được tạo với giá trị 0 — **service tự hồi phục**.
>
> Cơ chế tự reset đến từ chỗ ngày nằm ngay trong tên key
> (`spend:sv01:2026-08-10`), cộng với TTL 3 ngày. Không cần cron job, không cần
> ai nhớ dọn dẹp — sang ngày mới là key mới, và key cũ tự biến mất.
>
> Nói ngắn gọn: hạn mức tháng là một cái phanh **dùng một lần**; hạn mức ngày là
> cái phanh **tự nhả**. Với sự cố lúc 2h sáng — thời điểm không ai trực — khác
> biệt đó chính là khác biệt giữa "mất $1 và không ai biết" với "mất $30 và
> service chết cho đến khi có người vào cứu".
>
> Ngoài ra hạn mức ngày còn cho tín hiệu sớm hơn: một client tiêu hết $1 trong
> một ngày là bất thường và thấy ngay, trong khi cùng mức tiêu đó nằm trong hạn
> $30/tháng thì chỉ là 3% ngân sách, không có gì đáng chú ý.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Gốc rễ: hai loại probe dẫn tới **hai hành động khác nhau** của orchestrator.
> Liveness fail → **restart container**. Readiness fail → **rút khỏi load
> balancer, không restart**. Gộp làm một nghĩa là ép hành động thứ nhất xảy ra
> trong tình huống chỉ cần hành động thứ hai.
>
> **Thứ tự sự kiện khi Redis mất kết nối 30 giây (đã gộp):**
>
> 1. **t=0s** — Redis mất kết nối (restart, đổi node, hoặc mạng chớp).
> 2. **t≈0–10s** — Cả 3 container đều gọi `store.ping()` trong health check và
>    đều nhận `False`. Cả 3 cùng trả 503. Quan trọng: chúng fail **đồng thời**,
>    vì cùng phụ thuộc một Redis chứ không phải vì bản thân chúng hỏng.
> 3. **t≈10–30s** — Orchestrator đếm đủ số lần fail liên tiếp
>    (`retries=3`) và kết luận cả 3 container đều chết. Nó **giết và khởi động
>    lại cả ba cùng lúc**.
> 4. **t≈30s** — Redis hồi phục. Nhưng lúc này **không còn container nào đang
>    phục vụ**: cả 3 đang trong giai đoạn khởi động lại.
> 5. **t≈30–60s** — Ba container khởi động: nạp Python, import thư viện, chạy
>    lifespan, chờ qua `start_period`. Trong toàn bộ khoảng này mọi request đều
>    nhận 502/503.
> 6. **Hệ quả kéo dài** — Ba container cùng khởi động cùng lúc tạo đợt "sấm
>    sét": cùng mở kết nối tới Redis vừa hồi phục, cùng nhận traffic dồn lại.
>    Nếu Redis chưa ổn định hẳn, ping lại fail → **vòng lặp crash**, và
>    orchestrator bắt đầu backoff, khiến downtime kéo dài thêm.
>
> **Tổng kết: sự cố phụ thuộc 30 giây bị khuếch đại thành mất dịch vụ 60 giây
> trở lên, cộng nguy cơ crash loop.** Container hoàn toàn khỏe mạnh bị giết vì
> một thứ nằm ngoài chúng.
>
> **Khi tách đúng:** `/healthz` không chạm Redis nên vẫn trả 200 suốt 30 giây đó
> — không container nào bị restart. `/readyz` trả 503 nên load balancer tạm
> ngừng đẩy traffic vào. Đến t=30s Redis sống lại, `ping()` trả `True`,
> `/readyz` xanh trở lại, LB đẩy traffic vào **ngay lập tức** vì tiến trình chưa
> bao giờ chết. Thời gian gián đoạn đúng bằng 30 giây của sự cố gốc, không hơn.
>
> Đây là lý do bộ test dùng `inspect.signature` để ép `/healthz` **không** nhận
> tham số dependency nào, còn `/readyz` thì **bắt buộc** phải có — ranh giới này
> được kiểm tra ở mức chữ ký hàm chứ không chỉ ở kết quả trả về.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi mình gặp khi deploy lên Railway: **build thành công, nhưng mở URL ra
> 404.**
>
> Đây là triệu chứng đánh lừa nhất, vì 404 làm mình nghĩ ngay tới "sai đường
> dẫn" — kiểu gõ nhầm `/health` thay vì `/healthz`. Thử `/`, `/docs`, `/healthz`
> đều 404 như nhau thì mới thấy có gì đó không ổn ở tầng khác.
>
> **Bước 1 — xác định 404 này của ai.** Chạy `railway status`:
>
> ```
> day12-chat
>     status:  ● Failed
>     url:     https://day12-chat-production-8123.up.railway.app
> ```
>
> Service ở trạng thái `Failed`, tức là **không có replica nào đang chạy**. Vậy
> 404 là do edge của Railway trả về vì không có gì để chuyển tiếp request tới,
> chứ không phải FastAPI trả. Đây là phân biệt quan trọng: *404 của ứng dụng*
> nghĩa là app sống nhưng không có route đó; *404 của edge* nghĩa là app chết.
>
> **Bước 2 — đọc log thay vì đoán.** `railway logs --deployment`:
>
> ```
> Starting Container
> Usage: uvicorn [OPTIONS] APP
> Try 'uvicorn --help' for help.
> Error: Invalid value for '--port': '$PORT' is not a valid integer.
> ...
> 1/1 replicas never became healthy!
> Healthcheck failed!
> ```
>
> Log lặp lại nhiều lần — container crash-loop: khởi động, chết, Railway thử
> lại, chết tiếp, cho tới khi hết `restartPolicyMaxRetries`.
>
> **Bước 3 — nguyên nhân.** Chuỗi `$PORT` đi tới uvicorn **dưới dạng văn bản**
> chứ không được thay bằng số cổng. Truy ra file `railway.toml` mà lab cho sẵn:
>
> ```toml
> [deploy]
> startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
> ```
>
> `startCommand` của Railway **ghi đè `CMD` trong Dockerfile**, và nó được thực
> thi **không qua shell** — mà `$PORT` chỉ được nội suy khi có shell diễn giải.
> Không shell thì `$PORT` chỉ là 5 ký tự bình thường.
>
> Điều trớ trêu là `CMD` trong Dockerfile mình viết ở CP2 đã đúng ngay từ đầu:
>
> ```dockerfile
> CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
> ```
>
> Mình cố ý bọc `sh -c` chính vì lý do này — nhưng `startCommand` đã vô hiệu hoá
> nó.
>
> **Bước 4 — cách sửa.** Xoá hẳn dòng `startCommand` khỏi `railway.toml` để
> Railway dùng `CMD` của Dockerfile. Nhân tiện nâng `healthcheckTimeout` từ 30
> lên 100 giây cho rộng rãi. Deploy lại → `Deploy complete`, `/healthz` trả 200,
> `/readyz` trả `{"status":"ready","redis":true}`.
>
> **Một lỗi suýt gặp nữa:** Railway **không** tự nối add-on Redis vào service.
> Nếu chỉ chạy `railway add --database redis` mà không khai báo tham chiếu thì
> `REDIS_URL` không tồn tại trong service app, và triệu chứng sẽ là `/healthz`
> xanh nhưng `/readyz` trả 503 — đúng như thiết kế tách hai probe ở CP4 đã dự
> liệu. Mình xử lý bằng cú pháp tham chiếu biến giữa hai service:
>
> ```bash
> railway variables --service day12-chat --set 'REDIS_URL=${{Redis.REDIS_URL}}'
> ```
>
> Nó giải ra thành `redis://default:***@redis.railway.internal:6379`.
>
> **Bài học rút ra:** khi deploy hỏng, thứ tự đúng là **trạng thái → log →
> cấu hình**, không phải đoán từ mã HTTP. `curl` chỉ cho biết triệu chứng;
> `railway status` cho biết bệnh nằm ở tầng nào; `railway logs` mới cho biết
> nguyên nhân. Mình đã mất thời gian ban đầu vì tin vào con số 404.
>
> Và một điểm nữa: cấu hình do người khác cung cấp (ở đây là `railway.toml` của
> lab) không mặc nhiên đúng với Dockerfile của mình. Hai nơi cùng định nghĩa
> lệnh khởi động thì phải biết **nơi nào thắng** — ở Railway, `startCommand`
> thắng `CMD`.
