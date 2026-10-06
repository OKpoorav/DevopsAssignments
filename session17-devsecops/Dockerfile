# Hardened multi-stage image:
#  - builder stage installs the Python dependencies
#  - runtime stage: patched OS packages, NO pip/ensurepip (their vendored msgpack/urllib3/setuptools
#    carried HIGH CVEs found by the image scan), non-root user, healthcheck
FROM python:3.12-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/lib/python3.12/site-packages/pip* /usr/local/lib/python3.12/ensurepip /usr/local/bin/pip* \
    && useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
COPY --from=builder /install /usr/local
WORKDIR /app
COPY app ./app
USER 10001
EXPOSE 5001
HEALTHCHECK --interval=30s --timeout=3s CMD ["python", "-c", "import urllib.request;urllib.request.urlopen('http://localhost:5001/health')"]
CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "app.app:app"]
