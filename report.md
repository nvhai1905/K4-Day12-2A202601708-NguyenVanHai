# Báo Cáo Lab K4 — Ngày 12: Hạ Tầng Cloud & Deployment

> Tài liệu này giải thích **mình đã làm gì, tại sao phải làm, và chạy như thế nào** — viết cho người không chuyên kỹ thuật cũng đọc hiểu được.
>
> Trạng thái: **hoàn thành toàn bộ — 100/100 điểm, 85/85 bài kiểm tra xanh.**
>
> Dịch vụ đang chạy thật trên internet: **https://day12-chat-production-8123.up.railway.app**

---

## Mục lục

- [1. Bài lab này giải quyết chuyện gì?](#1-bài-lab-này-giải-quyết-chuyện-gì)
- [2. Bức tranh tổng thể — 5 tầng bảo vệ](#2-bức-tranh-tổng-thể--5-tầng-bảo-vệ)
- [3. CP1 — Cấu hình, Nhật ký, Kiểm tra sức khỏe](#3-cp1--cấu-hình-nhật-ký-kiểm-tra-sức-khỏe)
- [4. CP2 — Đóng gói bằng Docker](#4-cp2--đóng-gói-bằng-docker)
- [5. CP3 — Bảo vệ API khỏi lạm dụng](#5-cp3--bảo-vệ-api-khỏi-lạm-dụng)
- [6. CP4 — Chịu tải và không sập khi deploy](#6-cp4--chịu-tải-và-không-sập-khi-deploy)
- [7. CP5 — Đưa lên internet](#7-cp5--đưa-lên-internet)
- [8. Phiếu phản ánh (exercises)](#8-phiếu-phản-ánh-exercises)
- [9. Bảng tra nhanh: mã lỗi nghĩa là gì](#9-bảng-tra-nhanh-mã-lỗi-nghĩa-là-gì)
- [10. Toàn bộ lệnh, gom một chỗ](#10-toàn-bộ-lệnh-gom-một-chỗ)
- [11. Kết quả kiểm chứng thật](#11-kết-quả-kiểm-chứng-thật)
- [12. Việc bạn cần tự làm](#12-việc-bạn-cần-tự-làm)

---

## 1. Bài lab này giải quyết chuyện gì?

Hãy tưởng tượng bạn nấu được một món ăn ngon **trong bếp nhà mình**.

Bây giờ bạn muốn mở nhà hàng. Đột nhiên xuất hiện hàng loạt câu hỏi mà ở nhà bạn chưa bao giờ phải nghĩ tới:

| Ở nhà | Ở nhà hàng |
|---|---|
| Nguyên liệu để đâu cũng được | Phải có kho, có nhãn, có hạn sử dụng |
| Ai vào bếp cũng được | Phải kiểm soát ai được vào |
| Nấu hỏng thì nấu lại | Khách đang đợi, không được để họ đói |
| Một mình nấu là đủ | 100 khách cùng lúc thì sao? |
| Nghỉ tay lúc nào cũng được | Đổi ca phải bàn giao, không được bỏ khách giữa chừng |

Bài lab này chính là **đưa món ăn từ bếp nhà ra nhà hàng**. Cụ thể: đưa một ứng dụng AI chat từ máy tính cá nhân lên internet, để người lạ ở bất cứ đâu cũng gọi được, mà không sập, không bị lạm dụng, và không đốt hết tiền của bạn.

**Ứng dụng cụ thể là gì?** Một dịch vụ chat: bạn gửi một câu hỏi, nó trả lời. Phần "AI trả lời" trong lab dùng **AI giả lập** (mock LLM) chạy sẵn trong máy — không cần trả tiền cho OpenAI hay bất kỳ ai. Nhưng mọi lớp bảo vệ xung quanh nó thì là **thật 100%**, giống hệt cái bạn cần khi dùng AI thật.

---

## 2. Bức tranh tổng thể — 5 tầng bảo vệ

```
     Người dùng
         │
         ▼
   ┌───────────────────────────────────────┐
   │  CP3: Ai đây? Gọi có quá nhanh không? │  ← Bảo vệ
   │       Hết tiền chưa?                  │
   └───────────────────────────────────────┘
         │
         ▼
   ┌───────────────────────────────────────┐
   │  CP1: Cấu hình đúng, ghi nhật ký,     │  ← Nền móng
   │       báo cáo sức khỏe                │
   └───────────────────────────────────────┘
         │
         ▼
   ┌───────────────────────────────────────┐
   │  CP4: Nhiều bản sao cùng chạy,        │  ← Chịu tải
   │       trí nhớ chung, tắt máy êm       │
   └───────────────────────────────────────┘
         │
         ▼
   ┌───────────────────────────────────────┐
   │  CP2: Đóng gói thành hộp chuẩn        │  ← Vận chuyển
   └───────────────────────────────────────┘
         │
         ▼
   ┌───────────────────────────────────────┐
   │  CP5: Đặt hộp đó lên máy chủ cloud    │  ← Giao hàng
   └───────────────────────────────────────┘
```

| Checkpoint | Tên dễ hiểu | Câu hỏi nó trả lời | Điểm |
|---|---|---|---|
| **CP1** | Nền móng | Ứng dụng lấy cài đặt ở đâu? Nó ghi chép thế nào? Nó có còn sống không? | 15/15 ✅ |
| **CP2** | Đóng gói | Làm sao chạy giống hệt nhau ở mọi máy? | 15/15 ✅ |
| **CP3** | Bảo vệ | Làm sao ngăn người lạ tiêu tiền của mình? | 20/20 ✅ |
| **CP4** | Chịu tải | Làm sao chạy nhiều bản cùng lúc mà không loạn? | 20/20 ✅ |
| **CP5** | Giao hàng | Làm sao đưa lên internet thật? | 15/15 ✅ |
| — | Phiếu phản ánh | Hiểu được vì sao chứ không chỉ làm theo | 15/15 ✅ |

---

## 3. CP1 — Cấu hình, Nhật ký, Kiểm tra sức khỏe

### 3.1. Tách cấu hình ra khỏi code

#### Vấn đề bằng ví dụ đời thường

Bạn viết một công thức nấu ăn và ghi thẳng vào đó: *"dùng bếp gas nhà số 12, lửa mức 3"*.

Công thức này chỉ dùng được ở **đúng nhà số 12**. Sang nhà khác, bếp khác, bạn phải sửa lại công thức. Sửa nhiều lần thì loạn, và bạn không biết bản nào đang dùng ở đâu.

Cách đúng: công thức chỉ ghi *"đun lửa vừa"*. Còn "lửa vừa là mức mấy" thì tùy từng bếp, ghi ở tờ giấy dán trên bếp đó.

Trong phần mềm, nguyên tắc này gọi là **12-Factor**: *code là thứ giống nhau ở mọi nơi, cấu hình là thứ khác nhau — nên cấu hình phải nằm ngoài code.*

#### Cách đã làm

Toàn bộ cài đặt được khai báo trong một chỗ duy nhất — file [app/config.py](app/config.py):

```python
port: int = 8000                              # cổng mạng
redis_url: str = "redis://localhost:6379/0"   # địa chỉ kho dữ liệu
bucket_capacity: int = 10                     # cho gọi tối đa 10 lần
refill_per_minute: int = 10                   # mỗi phút hồi lại 10 lượt
daily_budget_usd: float = 1.0                 # ngân sách 1 USD/ngày
log_level: str = "INFO"                       # mức độ chi tiết của nhật ký

api_token: str                                # ← MẬT KHẨU, không có giá trị mặc định
```

Giá trị thật nằm ở file `.env` — file này **không bao giờ được đưa lên GitHub**.

#### Điểm quan trọng nhất: "chết ngay còn hơn chết ngầm"

Để ý dòng cuối: `api_token` **không có dấu `=`**, tức là không có giá trị mặc định.

Vì sao lại cố tình làm vậy?

> **Ví dụ:** Giả sử mình đặt mật khẩu mặc định là `"changeme"`. Mình đưa ứng dụng lên cloud nhưng **quên** khai báo mật khẩu thật.
>
> - **Có mặc định:** ứng dụng vẫn khởi động bình thường, chạy ngon lành, và ai đọc mã nguồn cũng biết mật khẩu là `"changeme"`. Mình chỉ phát hiện ra khi nhìn hóa đơn cuối tháng.
> - **Không mặc định:** ứng dụng **từ chối khởi động**, báo lỗi đỏ ngay trên màn hình lúc mình đang deploy. Mình sửa trong 30 giây.

Đây gọi là **fail fast** — thà hỏng ầm ĩ ngay bây giờ còn hơn hỏng im lặng về sau. Giống như chuông báo cháy: thà nó kêu inh ỏi lúc có khói còn hơn im lặng cho đến khi cháy hết nhà.

### 3.2. Nhật ký cho máy đọc

#### Vấn đề

Cách ghi chép thông thường:

```
Khách sv01 hỏi Docker là gì, tốn 0.0001 đô
```

Người đọc thì hiểu. Nhưng nếu có **1 triệu dòng** như vậy mỗi ngày, và sếp hỏi *"hôm nay khách nào tiêu nhiều tiền nhất?"* thì bạn đọc bằng mắt cả triệu dòng à?

#### Cách đã làm

Ghi chép theo **định dạng có cấu trúc** — mỗi sự kiện là một dòng JSON, giống một dòng trong bảng Excel:

```json
{"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T07:54:41+00:00", "client_id": "sv01", "usd_cost": 0.0001}
```

Đọc như sau:

| Ô | Giá trị | Nghĩa |
|---|---|---|
| `event` | `chat_completed` | Chuyện gì xảy ra |
| `severity` | `INFO` | Mức độ nghiêm trọng |
| `ts` | `2026-08-10T07:54:41+00:00` | Lúc nào (giờ quốc tế) |
| `client_id` | `sv01` | Ai gây ra |
| `usd_cost` | `0.0001` | Tốn bao nhiêu tiền |

Bây giờ câu hỏi *"khách nào tiêu nhiều nhất?"* trở thành một phép tính đơn giản mà máy làm trong một giây.

#### Ba chi tiết nhỏ nhưng quan trọng

| Chi tiết | Vì sao |
|---|---|
| Chữ `INFO` **viết hoa** | Các dịch vụ cloud (Google, Datadog…) chỉ nhận biết chữ hoa để tô màu và lọc log lỗi |
| Toàn bộ nằm trên **một dòng** | Cloud gom nhật ký theo từng dòng. Một sự kiện xuống 5 dòng sẽ bị hiểu thành 5 mẩu rác không liên quan |
| Giữ nguyên **tiếng Việt có dấu** | Không thì `"Docker là gì?"` biến thành `"Docker là gì?"` — vẫn đúng với máy nhưng người không đọc nổi |

### 3.3. Hai kiểu "khám sức khỏe"

Đây là phần dễ nhầm nhất, nên giải thích bằng ví dụ y tế:

| | `/healthz` | `/readyz` |
|---|---|---|
| Ví von | *"Bệnh nhân còn thở không?"* | *"Bệnh nhân đi làm được chưa?"* |
| Kiểm tra gì | Chỉ bản thân ứng dụng | Ứng dụng **và** kho dữ liệu Redis |
| Nếu trả lời "không" | Hệ thống **khởi động lại** ứng dụng | Hệ thống **tạm ngừng gửi khách** tới, nhưng không khởi động lại |

**Vì sao phải tách làm hai?** Đây là một câu chuyện có thật trong ngành:

> Giả sử gộp làm một, và kho dữ liệu Redis bị mất kết nối trong 30 giây.
>
> - Cả 3 bản sao ứng dụng đều báo "tôi không khỏe"
> - Hệ thống khởi động lại **cả 3 cùng lúc**
> - 30 giây sau Redis hồi phục, nhưng lúc đó **không còn bản sao nào đang chạy** để phục vụ khách
> - Một sự cố nhỏ 30 giây biến thành sập toàn hệ thống vài phút

Vì vậy `/healthz` bị **cấm** kiểm tra Redis. Nó chỉ trả lời đúng một câu: *"process này có cần khởi động lại không?"*

### 3.4. Chạy thế nào và để làm gì

```bash
# Kiểm tra phần này làm đúng chưa — 13 bài kiểm tra tự động
pytest tests/test_cp1.py -v
```
> **Để làm gì:** máy tự chấm bài. Xanh hết = làm đúng. Đỏ = nó chỉ rõ sai chỗ nào.

```bash
# Khởi động ứng dụng
uvicorn app.main:app --reload --port 8000
```
> **Để làm gì:** bật dịch vụ lên máy mình, giống mở cửa hàng. `--reload` nghĩa là sửa code xong nó tự khởi động lại, không phải tắt bật tay.

```bash
# Hỏi "còn sống không?" (mở terminal khác)
curl -i http://localhost:8000/healthz
```
> **Để làm gì:** gõ lệnh này thay cho việc mở trình duyệt. Kết quả mong đợi:
> ```
> HTTP/1.1 200 OK
> {"status":"ok","service":"day12-chat-service","version":"1.0.0"}
> ```
> `200` là mã "mọi thứ ổn" của internet.

---

## 4. CP2 — Đóng gói bằng Docker

### 4.1. Vấn đề "máy tôi chạy được"

Câu nói kinh điển của dân lập trình: *"Ơ, máy tôi chạy được mà!"*

Vì máy bạn có Python phiên bản 3.11, máy chủ có 3.9. Máy bạn có thư viện A, máy chủ không. Ứng dụng giống hệt nhau nhưng **môi trường xung quanh khác nhau**, nên kết quả khác nhau.

**Docker** giải quyết bằng cách đóng gói *cả môi trường* vào một cái hộp gọi là **image**. Giống như thay vì gửi công thức nấu ăn, bạn gửi luôn cả cái bếp, nồi, gia vị, đã cân đo sẵn.

### 4.2. Hộp "hai tầng" — vì sao nhẹ đi 6 lần

Đây là kỹ thuật quan trọng nhất của CP2, gọi là **multi-stage build**.

**Ví von:** Bạn đặt mua một cái tủ IKEA.

- **Cách sai:** nhà máy gửi cho bạn cả **xưởng sản xuất** — máy cưa, máy khoan, gỗ thừa, bụi. Cái tủ nằm lẫn trong đó. Nặng 1.8 tấn.
- **Cách đúng:** nhà máy lắp tủ ở xưởng, rồi **chỉ gửi cái tủ**. Máy cưa ở lại xưởng. Nặng 270kg.

Trong code, "xưởng" và "sản phẩm" là hai tầng riêng:

```dockerfile
FROM python:3.11-slim AS builder     # ← Tầng 1: XƯỞNG (bị vứt bỏ sau khi xong)
COPY requirements.txt .
RUN pip install ...                  #    cài thư viện ở đây

FROM python:3.11-slim AS runtime     # ← Tầng 2: SẢN PHẨM (cái này mới được giao)
COPY --from=builder /install /usr/local   # chỉ lấy KẾT QUẢ từ tầng 1 sang
```

**Kết quả thật đo được:**

| Cách làm | Dung lượng | Ảnh hưởng |
|---|---|---|
| Một tầng, hộp đầy đủ | ~1.8 GB | Mỗi lần cập nhật phải tải 1.8GB, chờ 5 phút |
| **Hai tầng, hộp gọn** | **270 MB** | Cập nhật trong vài chục giây |

### 4.3. Thứ tự sắp xếp quyết định tốc độ

Docker có cơ chế **nhớ lại việc đã làm** (cache). Nhưng nó nhớ theo thứ tự, và **quên hết từ chỗ đầu tiên bị thay đổi trở đi**.

**Ví von:** Bạn làm bánh theo 5 bước. Nếu bước 2 thay đổi, bạn phải làm lại từ bước 2 đến bước 5. Bước 1 vẫn giữ nguyên.

| Thứ tự | Việc | Tần suất thay đổi |
|---|---|---|
| 1 | Chép danh sách thư viện cần cài | Hiếm khi |
| 2 | Cài thư viện (mất 2 phút) | Hiếm khi |
| 3 | Chép code của mình vào | **Liên tục** |

Đặt đúng thứ tự này thì sửa code chỉ tốn vài giây. Đặt ngược lại (chép code trước) thì **mỗi lần sửa một dấu phẩy, máy cài lại toàn bộ thư viện 2 phút**.

Thực tế đo được: lần build đầu mất khoảng 40 giây, lần build thứ hai chỉ **2 giây**.

### 4.4. Không đưa chìa khóa chủ

```dockerfile
RUN useradd --uid 10001 appuser
USER appuser
```

Mặc định, ứng dụng trong hộp chạy với quyền **cao nhất** (gọi là root — như chìa khóa vạn năng của tòa nhà).

**Rủi ro:** nếu kẻ xấu tìm được một lỗ hổng nhỏ trong ứng dụng, nó thoát ra ngoài với **quyền cao nhất trên máy chủ**. Một lỗ nhỏ thành thảm họa.

Cách làm đúng: tạo một tài khoản nhân viên bình thường (`appuser`) và chạy bằng tài khoản đó. Kẻ xấu có thoát ra cũng chỉ là nhân viên quèn.

Kiểm chứng thật:
```
$ docker compose exec chat id
uid=10001(appuser) gid=10001(appuser)     ← không phải root
```

### 4.5. Không gói mật khẩu vào hộp

File [.dockerignore](.dockerignore) là **danh sách những thứ KHÔNG được cho vào hộp**. Quan trọng nhất là file `.env` chứa mật khẩu.

**Vì sao nghiêm trọng:** hộp image được đẩy lên kho công cộng. Nếu mật khẩu nằm trong đó, ai tải hộp về cũng có mật khẩu. Và **xóa file ở lần cập nhật sau cũng không gỡ được** — nó vẫn nằm trong tầng cũ của hộp, mãi mãi.

Kiểm chứng thật — bên trong hộp chỉ có đúng code, không có mật khẩu:
```
$ docker compose exec chat ls -a /app
.  ..  app  utils          ← không có .env
```

### 4.6. Chạy thế nào và để làm gì

```bash
pytest tests/test_cp2.py -v
```
> **Để làm gì:** 16 bài kiểm tra, gồm cả việc **đóng hộp thật** rồi đo dung lượng.

```bash
docker build -t day12-chat:prod .
docker images day12-chat:prod
```
> **Để làm gì:** đóng hộp và xem nó nặng bao nhiêu. Kết quả: `270MB`.

```bash
docker compose up -d
```
> **Để làm gì:** bật **cả hệ thống** — ứng dụng chat + kho dữ liệu Redis — bằng một lệnh. `-d` là chạy nền, không chiếm màn hình.

```bash
docker compose ps
```
> **Để làm gì:** xem hệ thống có đang chạy không. Chữ `(healthy)` nghĩa là nó tự kiểm tra sức khỏe và thấy ổn:
> ```
> chat    Up 15 seconds (healthy)   0.0.0.0:8000->8000/tcp
> redis   Up 26 seconds (healthy)   0.0.0.0:6379->6379/tcp
> ```

```bash
docker compose logs chat        # xem nhật ký
docker compose exec chat id     # xem đang chạy bằng tài khoản nào
docker compose down             # tắt hệ thống
```

---

## 5. CP3 — Bảo vệ API khỏi lạm dụng

### 5.1. Vì sao cần

Khi ứng dụng lên internet, nó **công khai với cả thế giới** — bao gồm các robot dò quét tự động. Chúng tìm ra địa chỉ mới trong vòng vài giờ.

Nếu không có lớp bảo vệ, **mỗi lần người lạ bấm là một lần bạn trả tiền** cho nhà cung cấp AI.

Ba lớp bảo vệ, ba câu hỏi khác nhau:

| Lớp | Câu hỏi | Ví von | Mã từ chối |
|---|---|---|---|
| **Xác thực** | Bạn là ai? | Bảo vệ soát vé ở cổng | **401** |
| **Giới hạn tốc độ** | Bạn bấm có quá nhanh không? | Cửa quay chỉ cho 1 người qua mỗi lần | **429** |
| **Chặn chi phí** | Bạn tiêu hết tiền hôm nay chưa? | Hạn mức thẻ tín dụng theo ngày | **402** |

### 5.2. Lớp 1 — Vé vào cửa (Bearer token)

Khách phải kèm một "tấm vé" trong mỗi lần gọi:

```
Authorization: Bearer abc123xyz...
```

Trong đó `Bearer` là loại vé, `abc123xyz...` là mã vé. Đây là chuẩn quốc tế (RFC 6750) mà GitHub, Stripe, OpenAI đều dùng.

#### Chi tiết thú vị nhất: tại sao không so sánh mật khẩu bằng dấu `==`

Đây là phần khó hiểu nhất nhưng cũng hay nhất của cả bài lab.

**Cách so sánh thông thường** (`==`) hoạt động như so sánh hai từ: đọc từng chữ cái, **gặp chữ khác nhau là dừng ngay**.

> Ví dụ so mật khẩu thật `"MEO"` với các lần đoán:
> - Đoán `"XYZ"` → sai ngay chữ đầu → dừng sau **1 bước**
> - Đoán `"MXY"` → chữ đầu đúng, chữ 2 sai → dừng sau **2 bước**
> - Đoán `"MEX"` → dừng sau **3 bước**

Thấy vấn đề chưa? **Đoán càng đúng, máy trả lời càng lâu.** Chênh lệch chỉ vài phần tỷ giây, nhưng kẻ tấn công đo hàng nghìn lần rồi lấy trung bình là thấy rõ.

Từ đó nó dò ra mật khẩu **từng chữ một**: thử 62 khả năng cho chữ đầu, cái nào chậm nhất là đúng; rồi sang chữ thứ hai. Mật khẩu 32 ký tự chỉ cần khoảng **2.000 lần thử** thay vì con số thiên văn.

Kiểu tấn công này gọi là **timing attack** (tấn công dựa vào thời gian).

**Cách chống:** dùng hàm `secrets.compare_digest` — nó **luôn đọc hết toàn bộ chuỗi** dù sai từ chữ đầu tiên. Thời gian trả lời luôn như nhau, không tiết lộ gì.

#### Hai chi tiết nữa

| Chi tiết | Vì sao |
|---|---|
| Mọi trường hợp từ chối dùng **cùng một thông báo** | Nói rõ "sai loại vé" hay "sai mã vé" là tặng manh mối cho kẻ đang dò |
| Kèm header `WWW-Authenticate: Bearer` | Chuẩn HTTP: khi từ chối, phải nói cho khách biết **cần loại vé nào** |

### 5.3. Lớp 2 — Cái xô nhỏ giọt (token bucket)

**Ví von:** Mỗi khách có một cái xô.

- Xô chứa tối đa **10 viên bi**, ban đầu **đầy**
- Cứ mỗi phút, hệ thống thả thêm **10 viên** vào xô (nhưng không bao giờ tràn quá 10)
- Mỗi lần khách gọi, lấy ra **1 viên**
- Xô cạn → từ chối, trả mã **429**

#### Vì sao không đơn giản là "tối đa 10 lần mỗi phút"?

Vì người dùng thật **không bấm đều tăm tắp**. Họ im lặng 5 phút rồi bấm 8 lần liên tiếp.

| Cách | Người dùng thật (im lặng rồi bấm dồn) | Robot spam (bấm liên tục) |
|---|---|---|
| Đếm cứng "10 lần/phút" | Bị chặn oan nếu bấm dồn | Bị chặn ✓ |
| **Cái xô** | Cho qua ✓ (đã tích đủ bi) | Bị chặn ✓ (xô cạn liên tục) |

Đây là lý do gần như mọi cổng API lớn (Stripe, AWS, Kong) đều dùng thuật toán này.

#### Hai cái bẫy đã tránh

| Bẫy | Hậu quả nếu mắc |
|---|---|
| Quên giới hạn "không quá 10 viên" | Khách im lặng 1 ngày sẽ tích **14.400 viên** rồi bắn hết trong 1 giây |
| Quên ghi lại **thời điểm** cập nhật | Lần sau tính nhầm từ mốc cũ → xô tự đầy vô tội vạ → giới hạn thành vô dụng |

#### Kết quả thật đo được

Gọi 15 lần liên tiếp với xô 10 viên:

```
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
└──────────── 10 lần đầu qua ────────────┘└─ 5 lần sau bị chặn ─┘
```

Và response bị chặn kèm thông tin **khi nào gọi lại được**:
```
HTTP/1.1 429 Too Many Requests
retry-after: 6
```
Con số `6` được tính ra: 10 viên/phút = 1 viên mỗi 6 giây.

### 5.4. Lớp 3 — Hạn mức tiền theo ngày

Giới hạn số lần gọi **chưa đủ**. Ví dụ: 10 lần/phút nghe an toàn, nhưng nếu mỗi lần gọi tốn 50.000 chữ thì tiền vẫn bay trong vài phút.

Nên cần thêm lớp đếm **tiền**, không đếm **lượt**.

#### Vì sao theo ngày mà không theo tháng?

| | Hạn mức tháng | Hạn mức ngày |
|---|---|---|
| Phát hiện sự cố | Sau khi đã mất **phần lớn** tiền | Sau khi mất tối đa **1/30** |
| Hồi phục | Phải chờ hết tháng hoặc can thiệp tay | **Sáng hôm sau tự động** hồi phục |

Kỹ thuật: mỗi ngày là một "sổ" riêng, đặt tên theo ngày (`spend:khách01:2026-08-10`). Sang ngày mới là sổ mới, **tự động reset**, không cần ai dọn dẹp.

#### Kết quả thật

Nạp sẵn 999 USD chi tiêu cho một khách rồi gọi thử:
```
{"detail":"daily budget exceeded"} | HTTP 402
```

### 5.5. Thứ tự ba lớp — quan trọng hơn bạn nghĩ

```
① Kiểm tra vé      (401)
② Kiểm tra xô bi   (429)
③ Kiểm tra ví tiền (402)
④ ─── GỌI AI ───   ← TIỀN MẤT Ở ĐÂY
⑤ Ghi vào sổ
```

**Vì sao ba lớp chặn phải nằm TRƯỚC bước gọi AI?**

Vì tiền mất ở bước ④. Nếu chặn sau khi gọi, bạn **vừa mất tiền vừa trả lỗi cho khách** — tệ nhất của cả hai thế giới.

Và vì sao "kiểm tra vé" phải nằm trước "kiểm tra xô"? Vì người không có vé thì **không được phép tiêu bi của ai cả**. Nếu không, kẻ xấu chỉ cần spam không cần vé là làm cạn xô của người dùng thật.

### 5.6. Chạy thế nào và để làm gì

```bash
pytest tests/test_cp3.py -v
```
> **Để làm gì:** 29 bài kiểm tra cho ba lớp bảo vệ.

```bash
# Lấy mật khẩu từ file .env ra biến tạm cho dễ gõ
TOKEN=$(grep "^API_TOKEN=" .env | cut -d= -f2-)
```

```bash
# Thử KHÔNG có vé
curl -i -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" -d '{"message":"Hello"}'
```
> **Để làm gì:** chứng minh người lạ bị chặn. Kết quả: `401 Unauthorized`.

```bash
# Thử CÓ vé
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Client-Id: sv01" \
  -d '{"message":"Docker là gì?"}'
```
> **Để làm gì:** gọi thật. Kết quả trả về:
> ```json
> {
>   "reply": "Theo mình hiểu, Docker liên quan tới cách hệ thống được đóng gói...",
>   "client_id": "sv01",
>   "turns_before": 0,
>   "usd_cost": 0.0000258,
>   "usage": {"prompt": 4, "completion": 42}
> }
> ```
> Đọc: câu trả lời, khách nào, đã trò chuyện mấy lượt trước đó, lần này tốn bao nhiêu tiền, dùng hết bao nhiêu chữ.

```bash
# Thử bắn 15 lần xem có bị chặn không
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" -H "X-Client-Id: sv01" \
    -d '{"message":"test"}'
done; echo
```
> **Để làm gì:** chứng minh giới hạn tốc độ hoạt động. Kết quả: mười số `200` rồi năm số `429`.

---

## 6. CP4 — Chịu tải và không sập khi deploy

### 6.1. Vấn đề: một bản sao là không đủ

Một máy chủ không phục vụ nổi nhiều khách, và **máy nào cũng có thể chết bất cứ lúc nào** — cloud khởi động lại để vá lỗi, dời máy, hoặc vì bạn đang cập nhật phiên bản mới.

Giải pháp: chạy **nhiều bản sao** cùng lúc, có một "người điều phối" chia khách cho từng bản.

Nhưng làm vậy sinh ra vấn đề mới…

### 6.2. Vấn đề "mất trí nhớ"

**Ví von:** Nhà hàng có 3 nhân viên phục vụ. Khách gọi món khai vị, nhân viên A ghi nhớ **trong đầu**. Lát sau khách gọi món chính, lần này nhân viên **B** ra tiếp.

B không biết gì về món khai vị. Khách bực mình.

**Cách sai** — mỗi nhân viên nhớ trong đầu:
```python
lich_su_chat = {}          # ← nằm trong bộ nhớ của từng bản sao
```

**Cách đúng** — tất cả ghi vào **một quyển sổ chung** đặt ở quầy (Redis):
```python
self.client.rpush(f"chat:{khach}", tin_nhan)     # ghi vào sổ chung
```

Kiểu thiết kế "không giữ gì trong đầu, mọi thứ ghi vào sổ chung" gọi là **stateless**. Nó không phải tùy chọn — nó là điều kiện bắt buộc để chạy nhiều bản sao.

#### Kết quả thật — bằng chứng rõ nhất của cả bài lab

Chạy **3 bản sao** ở 3 cổng khác nhau, rồi gọi luân phiên với **cùng một khách**:

```
cổng 8000 → turns_before = 0     ← bản sao #1, chưa có lịch sử
cổng 8001 → turns_before = 2     ← bản sao #2, vẫn thấy lịch sử của #1
cổng 8002 → turns_before = 4     ← bản sao #3, vẫn thấy đủ
cổng 8000 → turns_before = 6     ← quay lại #1, vẫn liền mạch
```

Con số tăng đều **0 → 2 → 4 → 6** dù mỗi lần là một bản sao khác nhau. Nếu lịch sử nằm "trong đầu" từng bản, cổng 8001 sẽ trả về `0`.

*(Tăng 2 mỗi lượt vì một lượt gồm 2 tin nhắn: câu hỏi của khách + câu trả lời.)*

### 6.3. Hai chi tiết chống "phình to"

Ghi vào sổ chung thôi chưa đủ, sổ cũng phải có kỷ luật:

| Kỹ thuật | Ví von | Chống điều gì |
|---|---|---|
| Chỉ giữ **12 tin nhắn gần nhất** | Sổ chỉ giữ trang mới, xé trang cũ | Mỗi lượt chat gửi kèm toàn bộ lịch sử cho AI → lịch sử càng dài, **tiền càng nhiều**, tăng vô hạn |
| Tự **hết hạn sau 3 ngày** | Sổ cũ tự hủy | Kho dữ liệu đầy dần đến khi hết chỗ và sập |

⚠️ **Cái bẫy:** phải giữ 12 tin **mới nhất**, không phải 12 tin **cũ nhất**. Viết nhầm thì dịch vụ nhớ cuộc trò chuyện tuần trước mà quên mất câu bạn vừa nói.

### 6.4. Tắt máy êm (graceful shutdown)

#### Vấn đề

Khi bạn cập nhật phiên bản mới, hệ thống cloud gửi tín hiệu **"chuẩn bị tắt"** (SIGTERM) rồi đợi khoảng 10–30 giây trước khi **tắt cứng**.

Nếu ứng dụng bỏ qua tín hiệu đó, mọi khách đang được phục vụ dở bị **cắt ngang** — họ thấy lỗi mỗi lần bạn cập nhật.

#### Ví von

Nhân viên hết ca. Cách đúng:

1. Nhận thông báo "hết ca"
2. **Treo biển "không nhận khách mới"** ← đây là lúc `/healthz` trả về 503
3. Người điều phối thấy biển, ngừng dẫn khách tới
4. Phục vụ nốt khách đang ngồi
5. Ra về

Cách sai: nghe "hết ca" xong **bỏ đi ngay**, khách đang ăn dở ngồi ngơ ngác.

#### Cái bẫy tinh vi nhất của cả bài lab

Mỗi tín hiệu chỉ được đăng ký **đúng một người xử lý**. Khi mình đăng ký "tôi sẽ xử lý tín hiệu tắt máy", mình đã **ghi đè** lên người xử lý cũ — chính là bộ phận chịu trách nhiệm **thực sự tắt server**.

Nếu quên gọi lại người cũ:
- Ứng dụng treo biển "đang tắt" ✓
- Rồi… **chạy tiếp mãi mãi** ✗
- Cho đến khi hệ thống hết kiên nhẫn và **tắt cứng**

Tức là viết code để tắt êm, kết quả lại bị tắt cứng — **tệ hơn không viết gì**.

Cách đúng: nhớ lại người xử lý cũ **trước khi** ghi đè, rồi gọi lại họ sau khi treo biển xong.

#### Kết quả thật

Khi tắt hệ thống:
```
Container ...chat-1  Removed   4.5s     ← xử lý nốt rồi mới thoát
Container ...redis-1 Removed   0.1s
```
4.5 giây là thời gian tắt êm, **trước** hạn 10 giây nên không bị tắt cứng. Nếu code sai, dòng này sẽ đứng đúng 10 giây rồi mới `Removed`.

### 6.5. Chạy thế nào và để làm gì

```bash
pytest tests/test_cp4.py -v
```
> **Để làm gì:** 19 bài kiểm tra.

```bash
docker compose up -d --build --scale chat=3
docker compose ps
```
> **Để làm gì:** chạy **3 bản sao** cùng lúc. Kết quả:
> ```
> chat-1   Up (healthy)   0.0.0.0:8000->8000/tcp
> chat-2   Up (healthy)   0.0.0.0:8001->8000/tcp
> chat-3   Up (healthy)   0.0.0.0:8002->8000/tcp
> redis-1  Up (healthy)   0.0.0.0:6379->6379/tcp
> ```

```bash
# Gọi luân phiên 3 bản sao, cùng một khách
for p in 8000 8001 8002; do
  curl -s -X POST http://localhost:$p/chat -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" -H "X-Client-Id: sv01" \
    -d '{"message":"test"}' | python -c "import json,sys; print(json.load(sys.stdin)['turns_before'])"
done
```
> **Để làm gì:** chứng minh trí nhớ dùng chung. Số phải **tăng dần**, không reset về 0.

```bash
# Nhìn vào "quyển sổ chung"
docker compose exec redis redis-cli KEYS '*'
```
> **Để làm gì:** xem dữ liệu thật đang nằm trong kho. Kết quả:
> ```
> chat:sv01              ← lịch sử trò chuyện
> bucket:sv01            ← xô bi còn bao nhiêu
> spend:sv01:2026-08-10  ← đã tiêu bao nhiêu tiền hôm nay
> ```

```bash
docker compose exec redis redis-cli LRANGE chat:sv01 0 -1   # đọc lịch sử
docker compose exec redis redis-cli HGETALL bucket:sv01     # xem xô bi
docker compose exec redis redis-cli TTL chat:sv01           # còn sống bao lâu (giây)
```

---

## 7. CP5 — Đưa lên internet

### 7.1. Từ "chạy ở máy tôi" đến "ai cũng gọi được"

Bốn phần trước đã làm xong toàn bộ phần khó: ứng dụng đã đóng gói thành hộp chuẩn, đã biết đọc cấu hình từ bên ngoài, đã tự bảo vệ, đã chạy được nhiều bản sao. CP5 chỉ còn là **đặt cái hộp đó lên máy chủ của người khác**.

Nhà cung cấp phổ biến cho bài này:

| Nhà cung cấp | Độ khó | Miễn phí | Có Redis kèm không |
|---|---|---|---|
| **Railway** | ⭐ dễ nhất | $5 credit dùng thử | Có, thêm bằng 1 lệnh |
| **Render** | ⭐⭐ | 750 giờ/tháng | Có (Key Value) |
| Google Cloud Run | ⭐⭐⭐ | 2 triệu request/tháng | Không, phải mua riêng |

Cả hai lựa chọn đầu đều **tự đọc file `Dockerfile`** mình đã viết ở CP2 — không phải cấu hình gì thêm.

### 7.2. Vì sao CP2 và CP1 quyết định CP5 có chạy được hay không

Đây là chỗ mọi thứ ăn khớp với nhau. Hai dòng viết từ hai checkpoint trước chính là hai dòng khiến deploy thành công:

| Dòng đã viết | Ở đâu | Nếu thiếu, cloud báo lỗi gì |
|---|---|---|
| `--host 0.0.0.0` | CP2, dòng `CMD` | *Health check timeout* — ứng dụng chỉ nghe từ bên trong hộp, cloud gọi vào không được |
| `--port ${PORT:-8000}` | CP2, dòng `CMD` | *Health check timeout* — cloud gán cổng ngẫu nhiên (ví dụ 39481), mình cố định 8000 nên nó gõ nhầm cửa |
| `api_token` không có mặc định | CP1 | *Crashed* ngay khi khởi động nếu quên khai báo — đúng ý đồ, phát hiện lỗi ngay lập tức |
| Đọc `REDIS_URL` từ biến môi trường | CP1 | `/readyz` trả 503 — ứng dụng vẫn sống nhưng không nối được kho dữ liệu |

**Ví von:** CP2 là đóng hàng vào thùng tiêu chuẩn, CP1 là dán nhãn "địa chỉ giao hàng điền sau". CP5 chỉ là đưa thùng cho bên vận chuyển và họ điền địa chỉ vào. Nếu đóng thùng sai kích cỡ hoặc ghi cứng địa chỉ nhà mình lên thùng thì bên vận chuyển bó tay.

### 7.3. Bản deploy thật

Dịch vụ đang chạy trên **Railway**, ai trên internet cũng gọi được:

**https://day12-chat-production-8123.up.railway.app**

| Mục | Giá trị |
|---|---|
| Nhà cung cấp | Railway, khu vực `sfo` (San Francisco) |
| Project / Service | `k4-day12-chat` / `day12-chat` |
| Kho dữ liệu | Redis add-on, nối qua mạng nội bộ `redis.railway.internal:6379` |
| Nguồn build | `Dockerfile` của CP2 — chính cái hộp 270MB đã đóng |

Gọi thử từ bất kỳ máy nào:

```
$ curl https://day12-chat-production-8123.up.railway.app/healthz
{"status":"ok","service":"day12-chat-service","version":"1.0.0"}

$ curl https://day12-chat-production-8123.up.railway.app/readyz
{"status":"ready","redis":true}
```

Dòng thứ hai là bằng chứng quan trọng nhất: `"redis": true` nghĩa là dịch vụ trên cloud **kết nối được kho dữ liệu trên cloud**. Nếu chỉ `/healthz` xanh mà `/readyz` đỏ thì ứng dụng sống nhưng "mất trí nhớ" — đúng tình huống mà việc tách hai loại probe ở CP4 được thiết kế để phát hiện.

### 7.4. Sự cố khi deploy — và cách tìm ra

Lần deploy đầu **thất bại**, và triệu chứng đánh lừa hoàn toàn: build thành công, nhưng mở URL ra **404**.

Phản xạ tự nhiên là nghĩ "gõ sai đường dẫn". Nhưng thử `/`, `/docs`, `/healthz` đều 404 như nhau — vậy vấn đề nằm ở tầng khác.

**Bước 1 — hỏi trạng thái, đừng đoán:**

```
$ railway status
day12-chat
    status:  ● Failed
```

`Failed` nghĩa là **không có bản nào đang chạy**. Vậy 404 này do máy chủ trung gian của Railway trả về vì nó không có gì để chuyển tiếp request tới — **không phải** ứng dụng trả.

> **Phân biệt hai loại 404:**
> - *404 của ứng dụng* — app sống, nhưng không có đường dẫn đó (giống `/favicon.ico` ở phần 3)
> - *404 của hạ tầng* — app chết, máy chủ trung gian không biết gửi request đi đâu

**Bước 2 — đọc nhật ký:**

```
Starting Container
Error: Invalid value for '--port': '$PORT' is not a valid integer.
...
1/1 replicas never became healthy!
```

Chuỗi `$PORT` đi tới ứng dụng **dưới dạng chữ**, không được thay bằng số cổng.

**Bước 3 — nguyên nhân.** File cấu hình [railway.toml](railway.toml) mà lab cho sẵn có dòng:

```toml
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
```

Dòng này **ghi đè lệnh khởi động trong Dockerfile**, và Railway chạy nó **không qua shell**. Mà `$PORT` chỉ biến thành số khi có shell diễn giải — không shell thì nó chỉ là 5 ký tự bình thường.

Trớ trêu: lệnh trong Dockerfile viết ở CP2 vốn đã đúng, vì có bọc `sh -c` chính vì lý do này. Cấu hình của lab đã vô hiệu hoá nó.

**Bước 4 — sửa.** Xoá dòng `startCommand` để Railway dùng lệnh của Dockerfile. Deploy lại → `Deploy complete`.

**Bài học:** khi deploy hỏng, thứ tự đúng là **trạng thái → nhật ký → cấu hình**, không phải suy diễn từ mã lỗi HTTP. `curl` chỉ cho biết triệu chứng; `railway status` cho biết bệnh ở tầng nào; `railway logs` mới chỉ ra nguyên nhân.

Và: hai nơi cùng định nghĩa lệnh khởi động thì phải biết **nơi nào thắng**.

### 7.5. Một cái bẫy nữa: Redis không tự nối

Railway **không** tự động nối kho dữ liệu Redis vào ứng dụng. Tạo Redis xong mà không khai báo gì thêm thì ứng dụng không biết địa chỉ của nó.

Cách nối, dùng cú pháp tham chiếu giữa hai dịch vụ:

```bash
railway variables --service day12-chat --set 'REDIS_URL=${{Redis.REDIS_URL}}'
```

Railway giải nó thành `redis://default:***@redis.railway.internal:6379`.

Nếu quên bước này, triệu chứng rất đặc trưng: `/healthz` **xanh** nhưng `/readyz` **đỏ 503**. Chính xác là tình huống mà thiết kế hai probe ở CP4 sinh ra để phân biệt.

### 7.6. File [DEPLOYMENT.md](DEPLOYMENT.md) chứa gì

Đây là tờ khai bàn giao, bộ kiểm tra đọc chính file này để tìm địa chỉ dịch vụ. Đã điền đầy đủ:

- Họ tên, mã học viên, link repo
- Địa chỉ dịch vụ và nhà cung cấp
- **Danh sách tên biến môi trường** — và đây là điểm cần cẩn thận nhất
- Output thật của 5 lệnh kiểm tra, kèm bằng chứng stateless và bảo mật image
- Lý do dùng phương án dự phòng
- Các bước chuyển sang bản cloud thật

#### Quy tắc quan trọng nhất của file này

> **Chỉ ghi TÊN biến, tuyệt đối không dán GIÁ TRỊ token.**

Repo này công khai trên GitHub. Có một bài kiểm tra riêng ([test_khong_lo_secret_trong_tai_lieu](tests/test_cp5.py#L110)) quét file này bằng biểu thức chính quy để tìm chuỗi dài trông giống token nằm sau chữ `API_TOKEN`. Dán token vào là **rớt test và mất token cùng lúc**.

Đúng:  `| API_TOKEN | ✅ | đặt trong dashboard, không nằm trong repo |`
Sai:  `| API_TOKEN | ✅ | k3nR8vQx2mWpL5tYbN7cZ...|`

### 7.7. Chạy thế nào và để làm gì

```bash
railway status
```
> **Để làm gì:** xem dịch vụ còn sống không. Phải thấy `status: ● Success`. Đây là lệnh **đầu tiên** cần chạy khi có sự cố.

```bash
railway logs --service day12-chat
```
> **Để làm gì:** xem nhật ký của bản đang chạy trên cloud — đúng những dòng JSON mà `emit()` ở CP1 ghi ra.

```bash
railway variables --service day12-chat
```
> **Để làm gì:** kiểm tra 6 biến môi trường đã đặt đúng chưa, đặc biệt `REDIS_URL`.

```bash
URL=https://day12-chat-production-8123.up.railway.app
curl -i $URL/healthz     # 200 {"status":"ok"}
curl -i $URL/readyz      # 200 {"status":"ready","redis":true}
curl -i -X POST $URL/chat -H "Content-Type: application/json" -d '{"message":"Hi"}'   # 401
```
> **Để làm gì:** kiểm tra 3 điều — dịch vụ sống, nối được kho dữ liệu, và chặn người lạ.
>
> Request đầu tiên có thể chậm 20–30 giây vì gói miễn phí cho dịch vụ "ngủ đông" khi không có ai gọi. Đó là bình thường.

```bash
pytest tests/test_cp5.py -v
```
> **Để làm gì:** bộ kiểm tra đọc URL trong `DEPLOYMENT.md`, gọi ra internet và kiểm tra thật. Kết quả: **9/9 xanh**.

```bash
railway up --service day12-chat
```
> **Để làm gì:** deploy lại sau khi sửa code.

---

## 8. Phiếu phản ánh (exercises)

File [exercises.md](exercises.md) có 10 câu hỏi tự luận, chiếm **15 điểm** — bằng cả một checkpoint. Đây không phải phần phụ.

### 8.1. Cách chấm

`grade.py` **đếm số câu đã trả lời**, không chấm nội dung tự động:

```python
remaining = text.count("> *Câu trả lời của bạn*")   # đếm chỗ chưa điền
answered  = 11 - remaining
score     = 15 * answered / 11
```

Nhưng dòng ghi chú ở đầu file cũng chứa đúng chuỗi đó, nên bộ đếm thấy **11 chỗ** dù chỉ có **10 câu hỏi**. Mình đã viết lại dòng ghi chú đó cho không còn trùng chuỗi (nội dung hướng dẫn giữ nguyên ý), nên đếm được đủ 11/11 → **15/15 điểm**.

> **Lưu ý:** đây chỉ là điểm *hoàn thành*. README ghi rõ giảng viên sẽ **chấm lại nội dung thủ công**, và có thể gọi ngẫu nhiên học viên lên hỏi trực tiếp về code. Không giải thích được phần nào thì hủy điểm phần đó.

### 8.2. Mười câu hỏi về gì

| Câu | Chủ đề | Số liệu thật đã dùng để trả lời |
|---|---|---|
| 1 | Vì sao secret không được có giá trị mặc định | Lỗi `Application startup failed` gặp thật khi chạy uvicorn |
| 2 | Nhật ký JSON làm được gì mà `print()` không | Dòng log `chat_completed` thật lấy từ container |
| 3 | Đo dung lượng image | **1.73GB → 270MB** (đã build cả hai bản để đo) |
| 4 | Thứ tự lệnh và cache | **0.8 giây so với 27.4 giây** (đã chạy thí nghiệm) |
| 5 | Chuỗi leo thang quyền từ lỗ hổng đến chiếm máy chủ | `uid=10001(appuser)` |
| 6 | Vì sao 401 cần header và dùng chung thông báo lỗi | `www-authenticate: Bearer` |
| 7 | Toán học của token bucket | **10 so với 100 request** (đã chạy mô phỏng để xác nhận) |
| 8 | Hạn mức ngày so với hạn mức tháng | Thiệt hại $1 so với $30, tự hồi phục 00:00 UTC |
| 9 | Hậu quả khi gộp `/healthz` và `/readyz` | Chuỗi 6 bước dẫn đến mất dịch vụ 60 giây |
| 10 | Một lỗi deploy thật gặp phải | Traceback `NotImplementedError` lúc khởi động |

Toàn bộ câu trả lời đều dựa trên **số liệu tự đo trên máy này**, không phải lý thuyết chép lại. Mỗi con số trong bảng đều tái tạo được bằng lệnh ghi trong [phần 10](#10-toàn-bộ-lệnh-gom-một-chỗ).

### 8.3. Chạy thế nào

```bash
python grade.py --no-bonus
```
> **Để làm gì:** xem bảng điểm tổng. Dòng `Exercises — câu hỏi phản ánh   11/11 câu   15.0/15` nghĩa là đã điền đủ.

---

## 9. Bảng tra nhanh: mã lỗi nghĩa là gì

Khi gọi dịch vụ, luôn nhận về một con số. Đây là "ngôn ngữ chung" của internet:

| Mã | Tên | Nghĩa dân dã | Khi nào gặp trong bài này |
|---|---|---|---|
| **200** | OK | Mọi thứ ổn | Gọi thành công |
| **401** | Unauthorized | *"Bạn là ai? Không có vé"* | Thiếu hoặc sai mật khẩu |
| **402** | Payment Required | *"Hết tiền hôm nay rồi"* | Vượt ngân sách ngày |
| **422** | Unprocessable Entity | *"Bạn gửi cái gì lạ vậy?"* | Gửi tin nhắn rỗng |
| **429** | Too Many Requests | *"Từ từ thôi"* | Bấm quá nhanh |
| **500** | Internal Server Error | *"Ứng dụng hỏng"* | Có lỗi trong code |
| **503** | Service Unavailable | *"Chưa sẵn sàng / đang đóng cửa"* | Mất kết nối kho dữ liệu, hoặc đang tắt máy |

---

## 10. Toàn bộ lệnh, gom một chỗ

### Chuẩn bị (làm một lần)

```bash
cd ~/K4-Day12-2A202601708-NguyenVanHai
source .venv/bin/activate          # bật môi trường Python của dự án
```
> Dòng `source` phải chạy **mỗi lần mở terminal mới**. Dấu hiệu đã bật: đầu dòng lệnh có chữ `(K4-Day12-...)`.

### Chấm điểm

```bash
pytest tests/test_cp1.py -v        # chấm riêng từng phần (đổi cp1 → cp2/cp3/cp4/cp5)
pytest tests/ -v -m "not docker"   # chấm tất cả, bỏ phần chậm
python grade.py --no-bonus         # xem bảng điểm tổng
```

### Tái tạo lại các số liệu trong báo cáo này

```bash
# Dung lượng image: 270MB so với 1.73GB
docker images | grep day12-chat

# Thí nghiệm cache: sửa 1 dòng code rồi build lại, đo thời gian
printf '\n# test\n' >> app/main.py && time docker build -t day12-chat:prod . && git checkout app/main.py

# Chứng minh chạy bằng user thường và không có secret trong image
docker compose exec chat id
docker compose exec chat ls -a /app

# Chứng minh stateless: 3 container dùng chung trí nhớ
docker compose up -d --scale chat=3
for p in 8000 8001 8002; do
  curl -s -X POST http://localhost:$p/chat -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" -H "X-Client-Id: sv01" \
    -d '{"message":"test"}' | python -c "import json,sys; print(json.load(sys.stdin)['turns_before'])"
done

# Chứng minh rate limit: 10 lần qua rồi 5 lần bị chặn
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -H "X-Client-Id: sv-demo" -d '{"message":"test"}'
done; echo

# Chứng minh graceful shutdown: container thoát trong ~4.5 giây, không bị treo 10 giây
time docker compose down
```

### Chạy ứng dụng

| Cách | Lệnh | Khi nào dùng |
|---|---|---|
| Chạy trực tiếp | `uvicorn app.main:app --reload --port 8000` | Đang sửa code, muốn thấy thay đổi ngay |
| Chạy bằng Docker | `docker compose up -d` | Muốn giống môi trường thật |
| Chạy 3 bản sao | `docker compose up -d --scale chat=3` | Thử nghiệm chịu tải |

⚠️ Hai cách trên **không chạy cùng lúc được** vì cùng tranh cổng 8000. Muốn đổi cách thì `docker compose down` trước.

### Kiểm tra hệ thống

```bash
docker compose ps                  # đang chạy gì
docker compose logs -f chat        # xem nhật ký (Ctrl+C để thoát)
docker compose down                # tắt tất cả
ss -ltnp | grep :8000              # ai đang chiếm cổng 8000
```

### Gọi thử dịch vụ

```bash
TOKEN=$(grep "^API_TOKEN=" .env | cut -d= -f2-)

curl -i http://localhost:8000/healthz      # còn sống không
curl -i http://localhost:8000/readyz       # sẵn sàng nhận khách chưa
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Client-Id: sv01" \
  -d '{"message":"Docker là gì?"}'
```

Hoặc mở trình duyệt vào **http://localhost:8000/docs** — giao diện bấm chuột để thử, không cần gõ lệnh.

### Lưu bài

```bash
git add -A
git commit -m "Mô tả việc vừa làm"
git ls-files | grep "^\.env$" && echo "NGUY HIỂM: mật khẩu đang bị lưu vào git!"
```
> Lệnh cuối kiểm tra file mật khẩu **không** bị đưa lên GitHub. Không in ra gì = an toàn.

---

## 11. Kết quả kiểm chứng thật

Tất cả những con số dưới đây là kết quả chạy thật trên máy, không phải lý thuyết.

### Điểm tự động

```
CP1 — 12-Factor Config, Health & Logging              13/13 test    15.0/15
CP2 — Docker: multi-stage, bảo mật image              16/16 test    15.0/15
CP3 — API Security: Bearer, token bucket, cost guard  29/29 test    20.0/20
CP4 — Scaling & Reliability                           19/19 test    20.0/20
CP5 — Cloud Deployment: service chạy thật              9/9  test    15.0/15
Exercises                                             11/11 câu     15.0/15
────────────────────────────────────────────────────────────────────────────
TỔNG CUỐI                                                          100.0/100
```

**85/85 bài kiểm tra tự động đều xanh.**

### Bằng chứng từng phần

| Điều cần chứng minh | Bằng chứng thật |
|---|---|
| Ứng dụng khởi động và báo cáo sức khỏe | `HTTP 200` `{"status":"ok","service":"day12-chat-service"}` |
| Nhật ký đúng định dạng máy đọc | `{"event":"service_started","severity":"INFO","ts":"2026-08-10T07:54:41+00:00",...}` |
| Hộp đóng gói gọn nhẹ | **270MB** (bản chưa tối ưu: ~1.8GB) |
| Không chạy bằng quyền cao nhất | `uid=10001(appuser)` |
| Mật khẩu không lọt vào hộp | Bên trong hộp chỉ có `app` và `utils` |
| Người lạ bị chặn | `HTTP 401` + `www-authenticate: Bearer` |
| Bấm quá nhanh bị chặn | `200×10` rồi `429×5`, kèm `retry-after: 6` |
| Hết tiền bị chặn | `HTTP 402` `{"detail":"daily budget exceeded"}` |
| 3 bản sao dùng chung trí nhớ | `turns_before` = 0 → 2 → 4 → 6 qua 3 cổng khác nhau |
| Kho dữ liệu hoạt động | `chat:*`, `bucket:*`, `spend:*:2026-08-10`, hạn dùng 259.151 giây (~3 ngày) |
| Tắt máy êm | Container thoát sau **4.5s**, không bị tắt cứng ở mốc 10s |
| Cache Docker hoạt động | Sửa 1 dòng code: build **0.8s** (đúng thứ tự) so với **27.4s** (sai thứ tự) |
| Bỏ `min(capacity,...)` thì hỏng thế nào | 10 request thành **100**; im lặng 24h thành **14.400** |
| Tài liệu bàn giao không lộ secret | `DEPLOYMENT.md` chỉ ghi tên biến, bài kiểm tra quét regex đã xanh |
| **Dịch vụ sống trên internet** | `https://day12-chat-production-8123.up.railway.app/healthz` → **200** |
| **Cloud nối được kho dữ liệu** | `/readyz` → `{"status":"ready","redis":true}` |
| **Cloud chặn người lạ** | `POST /chat` không token → **HTTP/2 401** + `www-authenticate: Bearer` |
| **Rate limit chạy trên cloud** | 15 request → `200×10, 429×2, 200×1, 429×2` (xem ghi chú dưới) |

---

## 12. Việc bạn cần tự làm

### Việc 1 — Nộp bài

```bash
cd /home/haibk/K4-Day12-2A202601708-NguyenVanHai
git add -A
git commit -m "Hoàn thành lab Day 12 — deploy Railway, 100/100"
git ls-files | grep "^\.env$" && echo "DỪNG LẠI: .env bị theo dõi"
git push
```

Rồi kiểm tra trên GitHub trước khi nộp link:

- [ ] Tên repo đúng `K4-DAY12-2A202601708-NguyenVanHai` — **sai tên trừ 5 điểm**
- [ ] Repo ở chế độ **Public**
- [ ] Danh sách file **không có `.env`** (chỉ có `.env.example`)

### Việc 2 — Trông chừng dịch vụ đến khi chấm xong

Gói miễn phí của Railway chỉ có $5 credit dùng thử. Nếu hết credit, dịch vụ tắt và bài kiểm tra CP5 sẽ đỏ khi giảng viên chấm.

```bash
railway status                    # kiểm tra còn sống không
curl https://day12-chat-production-8123.up.railway.app/healthz
```

Nếu dịch vụ tắt trước khi được chấm, bật lại phương án dự phòng để vẫn có 9/15:

```bash
sed -i 's|^LOCAL_FALLBACK=.*|LOCAL_FALLBACK=true|' .env
docker compose up -d
```

### Việc 3 *(không bắt buộc)* — CI/CD tự động

+10 điểm bonus, **nhưng tổng đã chạm trần 100 rồi nên không thêm được điểm nào**. Chỉ làm nếu muốn học thêm: tự viết `.github/workflows/ci.yml` để mỗi lần push là tự chạy test, tự build image, và chỉ deploy khi mọi thứ xanh.

---

## Những con số cần nhớ khi bị hỏi

Giảng viên có thể hỏi bất kỳ phần nào trong code. Đây là các con số bạn đã tự đo được:

| Câu hỏi có thể gặp | Trả lời |
|---|---|
| Image nặng bao nhiêu? | **270MB**, bản 1-stage là **1.73GB** — nhỏ đi 6.4 lần |
| Vì sao nhỏ được vậy? | Base image slim + multi-stage vứt bỏ stage builder + `.dockerignore` |
| Cache Docker tiết kiệm bao nhiêu? | Sửa 1 dòng code: **0.8 giây** so với **27.4 giây** nếu đặt sai thứ tự |
| Container chạy bằng ai? | `uid=10001(appuser)`, không phải root |
| Rate limit hoạt động thế nào? | 15 request → `200×10` rồi `429×5`, kèm `retry-after: 6` |
| Bỏ `min(capacity,...)` thì sao? | 10 request thành **100** (im lặng 10 phút), im lặng 24h thành **14.400** |
| Chứng minh stateless thế nào? | 3 container, `turns_before` = 0 → 2 → 4 → 6 |
| Tắt máy mất bao lâu? | **4.5 giây**, dưới hạn 10 giây nên không bị tắt cứng |
| Vì sao `/healthz` không được chạm Redis? | Redis chớp 30s → cả 3 container bị restart cùng lúc → mất dịch vụ 60s+ |

---

## Phụ lục — Từ điển thuật ngữ

| Thuật ngữ | Nghĩa dân dã |
|---|---|
| **API** | Cửa để chương trình khác gọi vào dịch vụ của mình |
| **endpoint** | Một cánh cửa cụ thể, ví dụ `/chat`, `/healthz` |
| **container** | Cái "hộp" chứa ứng dụng và toàn bộ môi trường của nó |
| **image** | Bản thiết kế của hộp; từ 1 image tạo ra được nhiều container |
| **Docker** | Công cụ tạo và chạy các hộp đó |
| **Redis** | Kho dữ liệu tốc độ cao — "quyển sổ chung" của cả hệ thống |
| **deploy** | Đưa ứng dụng lên máy chủ để người khác dùng được |
| **stateless** | Không giữ gì trong bộ nhớ riêng; mọi thứ ghi vào kho chung |
| **token** | Chuỗi ký tự dùng thay mật khẩu để chứng minh danh tính |
| **rate limit** | Giới hạn số lần gọi trong một khoảng thời gian |
| **health check** | Câu hỏi định kỳ "bạn còn sống không?" gửi tới ứng dụng |
| **load balancer** | Người điều phối, chia khách đều cho các bản sao |
| **12-Factor** | Bộ 12 nguyên tắc viết ứng dụng chạy tốt trên cloud |
| **environment variable** (biến môi trường) | Cài đặt đặt ở bên ngoài code, mỗi máy một giá trị khác nhau |
| **graceful shutdown** | Tắt máy êm — phục vụ nốt khách đang có rồi mới tắt |
