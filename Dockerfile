# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (bản production-ready)
#
# Stage `builder`: cài dependency, được phép nặng — nó bị vứt đi.
# Stage `runtime`: chỉ nhận kết quả cài đặt → image nhỏ, không có compiler.
#
# Build thử:  docker build -t day12-chat:prod .
#             docker images day12-chat:prod
# Kiểm tra:   pytest tests/test_cp2.py -v
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements TRƯỚC rồi mới cài: Docker cache theo layer, nên sửa một
# dòng code không làm mất cache của bước cài thư viện.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.11-slim AS runtime

# Không sinh .pyc trong container; log đẩy thẳng ra stdout không giữ trong
# buffer — container bị kill mà log còn kẹt trong buffer là mất log.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Chỉ mang KẾT QUẢ cài đặt từ builder sang, không mang theo pip cache/compiler.
COPY --from=builder /install /usr/local

# Code copy sau cùng — layer thay đổi nhiều nhất nằm cuối để cache tối ưu.
COPY app ./app
COPY utils ./utils

# Container chạy bằng user thường: ai thoát được khỏi app cũng không thành
# root trên host.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Docker tự gọi endpoint này để biết container còn phục vụ được không.
# Đọc PORT từ env để khớp với CMD bên dưới.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/healthz' % os.getenv('PORT', '8000')).read()" || exit 1

# 0.0.0.0 chứ không phải 127.0.0.1: bind localhost thì ngoài container không
# gọi vào được. ${PORT:-8000} vì Railway/Render/Cloud Run tự gán cổng.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]