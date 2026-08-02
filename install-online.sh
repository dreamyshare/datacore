#!/usr/bin/env bash
# AI Bridge / datacore_mcp 在线一键安装（拉取 GHCR 镜像，无需本地源码构建）
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/jessdy/ai-bridge/main/retail-mcp/deploy/install-online.sh | bash
#
# 可选环境变量：
#   INSTALL_DIR=...              安装目录，默认 ~/datacore_mcp
#   REPO_RAW=...                 GitHub raw 根，默认官方仓库 main
#   DATACORE_IMAGE=...           MCP 镜像
#   DATACORE_ADMIN_IMAGE=...     Admin 镜像（默认同族）
#   ADMIN_PASSWORD=...           管理台密码（未设置则自动生成）
#   MYSQL_DOCKER_PASSWORD=...    MySQL 密码（未设置则自动生成）
#   MANAGER_PUBLIC_URL=...       安装上报地址（可选）
#   LICENSE_REPORT_URL=...       完整上报 URL（可选，优先）
set -euo pipefail

log() { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/jessdy/ai-bridge/main}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/datacore_mcp}"
DATACORE_IMAGE="${DATACORE_IMAGE:-ghcr.io/jessdy/datacore_mcp:latest}"
DATACORE_ADMIN_IMAGE="${DATACORE_ADMIN_IMAGE:-ghcr.io/jessdy/datacore_mcp-admin:latest}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1" >&2
    exit 1
  fi
}

require_cmd docker
require_cmd curl
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "需要 Docker Compose（docker compose 或 docker-compose）" >&2
  exit 1
fi

rand_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '/+=\n' | head -c 24
  else
    # fallback
    head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 24
  fi
}

set_env_kv() {
  local key="$1" value="$2" file="$3"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    # 使用 | 分隔，避免密码中的 / 破坏 sed
    local escaped
    escaped=$(printf '%s' "$value" | sed -e 's/[|&]/\\&/g')
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "$file"
    rm -f "${file}.bak"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

download() {
  local url="$1" dest="$2"
  log "下载 $(basename "$dest")"
  curl -fsSL "$url" -o "$dest"
}

mkdir -p "$INSTALL_DIR/tools"
cd "$INSTALL_DIR"

if [[ "${SKIP_DOWNLOAD:-0}" == "1" ]]; then
  log "跳过远程下载（使用安装目录内已有文件）"
  for f in docker-compose.yml .env.example schema.sql; do
    if [[ ! -f "$f" ]]; then
      echo "缺少 $INSTALL_DIR/$f（SKIP_DOWNLOAD=1 时需预先准备）" >&2
      exit 1
    fi
  done
else
  download "${REPO_RAW}/retail-mcp/deploy/docker-compose.online.yml" "${INSTALL_DIR}/docker-compose.yml"
  download "${REPO_RAW}/retail-mcp/.env.example" "${INSTALL_DIR}/.env.example"
  download "${REPO_RAW}/schema.sql" "${INSTALL_DIR}/schema.sql"
fi

GENERATED_NOTE=""
if [[ ! -f .env ]]; then
  log "创建 .env"
  cp .env.example .env

  MYSQL_PASS="${MYSQL_DOCKER_PASSWORD:-${MYSQL_PASSWORD:-}}"
  ADMIN_PASS="${ADMIN_PASSWORD:-}"
  if [[ -z "$MYSQL_PASS" ]]; then
    MYSQL_PASS="$(rand_secret)"
    GENERATED_NOTE="${GENERATED_NOTE}MYSQL_DOCKER_PASSWORD=${MYSQL_PASS}\n"
  fi
  if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS="$(rand_secret)"
    GENERATED_NOTE="${GENERATED_NOTE}ADMIN_PASSWORD=${ADMIN_PASS}\n"
  fi
  SECRET_KEY="$(rand_secret)$(rand_secret)"

  set_env_kv MYSQL_DOCKER_PASSWORD "$MYSQL_PASS" .env
  set_env_kv MYSQL_DOCKER_ROOT_PASSWORD "$MYSQL_PASS" .env
  set_env_kv MYSQL_PASSWORD "$MYSQL_PASS" .env
  set_env_kv ADMIN_PASSWORD "$ADMIN_PASS" .env
  set_env_kv ADMIN_SECRET_KEY "$SECRET_KEY" .env
  set_env_kv DATACORE_IMAGE "$DATACORE_IMAGE" .env
  set_env_kv DATACORE_ADMIN_IMAGE "$DATACORE_ADMIN_IMAGE" .env
  if [[ -n "${MANAGER_PUBLIC_URL:-}" ]]; then
    set_env_kv MANAGER_PUBLIC_URL "$MANAGER_PUBLIC_URL" .env
  fi
  if [[ -n "${LICENSE_REPORT_URL:-}" ]]; then
    set_env_kv LICENSE_REPORT_URL "$LICENSE_REPORT_URL" .env
  fi
else
  log "沿用已有 .env"
  set_env_kv DATACORE_IMAGE "$DATACORE_IMAGE" .env
  set_env_kv DATACORE_ADMIN_IMAGE "$DATACORE_ADMIN_IMAGE" .env
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${ADMIN_PORT:=8767}"
: "${MCP_PORT:=8765}"
: "${MANAGER_PUBLIC_URL:=}"
: "${LICENSE_REPORT_URL:=}"
DATACORE_IMAGE="${DATACORE_IMAGE:-ghcr.io/jessdy/datacore_mcp:latest}"
DATACORE_ADMIN_IMAGE="${DATACORE_ADMIN_IMAGE:-ghcr.io/jessdy/datacore_mcp-admin:latest}"

log "拉取镜像"
docker pull "$DATACORE_IMAGE"
docker pull "$DATACORE_ADMIN_IMAGE"
docker pull mysql:8.4

log "启动服务"
"${COMPOSE[@]}" -f docker-compose.yml up -d

ADMIN_BASE="http://127.0.0.1:${ADMIN_PORT}"
log "等待管理后台就绪: ${ADMIN_BASE}"
ready=0
for _ in $(seq 1 90); do
  if curl -fsS "${ADMIN_BASE}/api/session" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" -ne 1 ]]; then
  warn "管理后台尚未就绪，继续尝试签发 License / 上报"
fi

log "确认本地 License"
LICENSE_JSON=""
if docker exec datacore_mcp python -c 'import license_runtime, json; print(json.dumps(license_runtime.ensure_license(), ensure_ascii=False))' >/tmp/ai-bridge-license-status.json 2>/tmp/ai-bridge-license-status.err; then
  LICENSE_JSON="$(cat /tmp/ai-bridge-license-status.json)"
else
  warn "容器内签发 License 失败（安装仍继续）:"
  cat /tmp/ai-bridge-license-status.err >&2 || true
fi

if docker exec datacore_mcp python -c '
import license_runtime
p = license_runtime.license_path()
print(p.read_text(encoding="utf-8") if p.is_file() else "")
' >/tmp/ai-bridge-license-doc.json 2>/dev/null; then
  :
fi

REPORT_URL="${LICENSE_REPORT_URL:-}"
if [[ -z "$REPORT_URL" && -n "${MANAGER_PUBLIC_URL}" ]]; then
  REPORT_URL="${MANAGER_PUBLIC_URL%/}/api/public/install-report"
fi

if [[ -z "$REPORT_URL" ]]; then
  warn "未配置 MANAGER_PUBLIC_URL / LICENSE_REPORT_URL，跳过安装上报"
elif [[ -z "$LICENSE_JSON" ]]; then
  warn "无 License 状态可上报，跳过"
else
  log "向 manager 上报安装信息: ${REPORT_URL}"
  set +e
  if command -v python3 >/dev/null 2>&1; then
    PY=python3
  else
    PY=python
  fi
  "$PY" - "$REPORT_URL" <<'PY'
import json, socket, sys, urllib.request

url = sys.argv[1]
try:
    with open("/tmp/ai-bridge-license-status.json", encoding="utf-8") as f:
        status = json.load(f)
except Exception as exc:
    print(f"读取 License 状态失败: {exc}", file=sys.stderr)
    sys.exit(0)

license_doc = None
try:
    with open("/tmp/ai-bridge-license-doc.json", encoding="utf-8") as f:
        raw = f.read().strip()
        if raw:
            license_doc = json.loads(raw)
except Exception:
    pass

payload = {
    "machine_code": status.get("machine_code") or "",
    "license_key": status.get("license_key"),
    "edition": status.get("edition"),
    "product": status.get("product") or "ai-bridge",
    "valid_until": status.get("valid_until") or status.get("free_valid_until"),
    "hostname": socket.gethostname(),
}
if license_doc is not None:
    payload["license"] = license_doc
if not payload["machine_code"]:
    print("机器码为空，跳过上报", file=sys.stderr)
    sys.exit(0)

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json", "User-Agent": "ai-bridge-install-online/1.0"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=12) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        print(f"上报成功 HTTP {resp.status}: {body[:300]}")
except Exception as exc:
    print(f"上报失败（不影响安装）: {exc}", file=sys.stderr)
PY
  set -e
fi

rm -f /tmp/ai-bridge-license-status.json /tmp/ai-bridge-license-status.err /tmp/ai-bridge-license-doc.json 2>/dev/null || true

cat <<EOF

安装完成。

  目录:   ${INSTALL_DIR}
  MCP:    http://127.0.0.1:${MCP_PORT}/mcp
  Admin:  http://127.0.0.1:${ADMIN_PORT}/
  账号:   ${ADMIN_USERNAME:-admin}

镜像:
  ${DATACORE_IMAGE}
  ${DATACORE_ADMIN_IMAGE}

请在管理台右上角查看 License；正式版可粘贴 manager 签发的 .license 导入。
EOF

if [[ -n "$GENERATED_NOTE" ]]; then
  printf '\n已自动生成凭据（请立即保存，仅显示一次）:\n%b\n' "$GENERATED_NOTE"
fi
