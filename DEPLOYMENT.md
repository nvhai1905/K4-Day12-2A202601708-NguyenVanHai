# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Văn Hải |
| Mã học viên | 2A202601708 |
| Repo | https://github.com/nvhai1905/K4-DAY12-2A202601708-NguyenVanHai |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-chat-production-8123.up.railway.app |
| Platform | Railway (region `sfo`, project `k4-day12-chat`, service `day12-chat`) |
| Ngày deploy | 2026-08-10 |
| Redis | Railway Redis add-on, kết nối qua mạng nội bộ `redis.railway.internal:6379` |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán; `CMD` đọc bằng `${PORT:-8000}` |
| `API_TOKEN` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Redis add-on của platform; ở máy là `redis://redis:6379/0` do compose cấp |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/healthz

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/readyz

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Client-Id: sv-test" \
  -d '{"message":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" \
    -d '{"message":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Output thu được lúc 2026-08-10, gọi vào **bản deploy trên Railway**
(`<URL>` = `https://day12-chat-production-8123.up.railway.app`):

```
$ curl -s <URL>/healthz
{"status":"ok","service":"day12-chat-service","version":"1.0.0"} | HTTP 200

$ curl -s <URL>/readyz
{"status":"ready","redis":true} | HTTP 200
      ↑ chứng minh service trên cloud kết nối được Redis add-on

$ curl -D- -X POST <URL>/chat         # không token
HTTP/2 401
www-authenticate: Bearer

$ curl -X POST <URL>/chat             # có token
{
    "reply": "Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa
              môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.",
    "client_id": "cp5-cloud",
    "turns_before": 0,
    "usd_cost": 2.145e-05,
    "usage": {"prompt": 3, "completion": 35}
}

$ 15 request liên tiếp                # rate limit, xô 10 token
200 200 200 200 200 200 200 200 200 200 429 429 200 429 429
```

Lưu ý cái `200` ở lần thứ 13: khác với khi chạy ở máy (`200×10` rồi `429×5`
liền mạch), gọi qua Internet mất khoảng 0.5 giây mỗi vòng, nên 12 request đầu
kéo dài hơn 6 giây — vừa đủ để xô nhỏ thêm 1 token với tốc độ 10 token/phút.
Đây là hành vi **đúng** của token bucket, không phải lỗi: nó giới hạn theo tốc
độ trung bình chứ không phải theo bộ đếm cứng.

Trước khi lên cloud, cùng bộ lệnh đó chạy trên Docker Compose tại máy:

```
$ docker compose ps
SERVICE   STATUS                    PORTS
chat      Up 44 minutes (healthy)   0.0.0.0:8000->8000/tcp
redis     Up 44 minutes (healthy)   0.0.0.0:6379->6379/tcp

$ 15 request liên tiếp
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429

$ curl -sD- ... | grep retry-after
HTTP/1.1 429 Too Many Requests
retry-after: 6
```

Kiểm chứng thêm về stateless — chạy `docker compose up -d --scale chat=3` rồi
gọi luân phiên 3 container với cùng một `X-Client-Id`:

```
cổng 8000 → turns_before = 0
cổng 8001 → turns_before = 2
cổng 8002 → turns_before = 4
cổng 8000 → turns_before = 6
```

Số tăng liên tục dù đổi container, chứng minh lịch sử hội thoại nằm ở Redis
chứ không nằm trong RAM của từng process.

Bảo mật image, kiểm chứng bên trong container đang chạy:

```
$ docker compose exec chat id
uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)

$ docker compose exec chat ls -a /app
.  ..  app  utils                      # không có .env trong image

$ docker images day12-chat:prod
day12-chat:prod   270MB                # bản 1-stage trước đó: 1.73GB
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/healthz.png` — kết quả gọi `/healthz` từ trình duyệt hoặc curl

---

## Các Bước Đã Làm Để Deploy

```bash
railway login
railway init                                  # project: k4-day12-chat
railway add --database redis                  # tạo Redis add-on
railway add --service day12-chat              # tạo service cho app

railway variables --service day12-chat \
  --set "API_TOKEN=<token của service, đọc từ .env, không gõ ra màn hình>" \
  --set 'REDIS_URL=${{Redis.REDIS_URL}}' \
  --set "BUCKET_CAPACITY=10" \
  --set "REFILL_PER_MINUTE=10" \
  --set "DAILY_BUDGET_USD=1.0" \
  --set "LOG_LEVEL=INFO"

railway up --service day12-chat
railway domain --service day12-chat
```

Hai chi tiết đáng ghi lại:

- **`REDIS_URL=${{Redis.REDIS_URL}}`** — Railway **không** tự nối add-on Redis
  vào service khác. Đây là cú pháp tham chiếu biến giữa hai service, giải ra
  thành `redis://default:***@redis.railway.internal:6379`. Thiếu bước này thì
  `/healthz` vẫn 200 nhưng `/readyz` trả 503.
- **Không set biến `PORT`** — Railway tự gán, `Dockerfile` đọc bằng
  `${PORT:-8000}`.

## Sự Cố Gặp Phải Khi Deploy

**Triệu chứng:** build thành công nhưng truy cập URL trả **404**, dashboard báo
service `Failed`.

**Nguyên nhân** — đọc `railway logs --deployment`:

```
Starting Container
Usage: uvicorn [OPTIONS] APP
Error: Invalid value for '--port': '$PORT' is not a valid integer.
...
1/1 replicas never became healthy!
Healthcheck failed!
```

`railway.toml` bản gốc khai báo:

```toml
[deploy]
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
```

`startCommand` của Railway **ghi đè `CMD` trong Dockerfile** và được thực thi
**không qua shell**, nên chuỗi `$PORT` đi thẳng tới uvicorn dưới dạng văn bản
thay vì được thay bằng số cổng. Container crash-loop, không replica nào healthy,
và Railway edge trả 404 vì không có bản nào đang chạy — 404 ở đây là của
Railway, không phải của FastAPI.

**Cách sửa:** xoá `startCommand` khỏi `railway.toml` để Railway dùng `CMD` của
Dockerfile, vốn đã bọc trong `sh -c` nên shell nội suy được biến:

```dockerfile
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
```

Đồng thời nâng `healthcheckTimeout` từ 30s lên 100s cho rộng rãi. Deploy lại →
`Deploy complete`, `/healthz` trả 200.

**Bài học:** khi platform báo 404, phân biệt "404 của ứng dụng" (route không
tồn tại) với "404 của edge" (không có instance nào sống). Thứ phân biệt được
hai cái đó là `railway status` và `railway logs`, không phải `curl`.

## Phương Án Dự Phòng (không dùng — giữ lại để tham khảo)

Trước khi deploy cloud, bài đã chạy đầy đủ bằng Docker Compose tại máy với
`LOCAL_FALLBACK=true`. Cách bật lại nếu cần:

1. Đặt `LOCAL_FALLBACK=true` trong `.env`
2. `docker compose up -d` rồi kiểm tra `docker compose ps`
3. `pytest tests/test_cp5.py -v` — bộ test tự chuyển sang gọi `http://localhost:8000`

Điểm CP5 khi đó bị trần ở 9/15.
