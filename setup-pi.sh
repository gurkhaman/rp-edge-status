#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="rp-edge-status"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_USER="${USER}"
PYTHON_VERSION="3.12"
ACTION="${1:-start}"

if [[ "${EUID}" -eq 0 ]]; then
    printf 'Run this script as the normal Pi user, not as root.\n' >&2
    exit 1
fi

if [[ ! -f "${REPO_DIR}/app.py" || ! -f "${REPO_DIR}/pyproject.toml" ]]; then
    printf 'Run this script from the cloned rp-edge-status repository.\n' >&2
    exit 1
fi

if [[ "${ACTION}" == "stop" ]]; then
    sudo -v
    sudo systemctl stop "${SERVICE_NAME}"

    if [[ -x "${REPO_DIR}/.venv/bin/python" ]]; then
        "${REPO_DIR}/.venv/bin/python" - <<'EOF'
from app import BLUE_PIN, GREEN_PIN, LED_COMMON_ANODE, RED_PIN, USE_GPIO

if USE_GPIO:
    from gpiozero import RGBLED

    led = RGBLED(
        red=RED_PIN,
        green=GREEN_PIN,
        blue=BLUE_PIN,
        active_high=not LED_COMMON_ANODE,
    )
    led.off()
    led.close()
EOF
    fi

    printf 'Service stopped.\n'
    exit 0
fi

if [[ "${ACTION}" != "start" ]]; then
    printf 'Usage: bash setup-pi.sh [stop]\n' >&2
    exit 1
fi

if command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
else
    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        printf 'Install curl or wget first so uv can be installed.\n' >&2
        exit 1
    fi

    UV_BIN="${HOME}/.local/bin/uv"

    if [[ ! -x "${UV_BIN}" ]]; then
        printf 'uv installation finished but %s was not found.\n' "${UV_BIN}" >&2
        exit 1
    fi
fi

sudo -v

if ! id -nG "${SERVICE_USER}" | tr ' ' '\n' | grep -qx gpio; then
    sudo usermod -aG gpio "${SERVICE_USER}"
    ADDED_GPIO_GROUP=1
else
    ADDED_GPIO_GROUP=0
fi

"${UV_BIN}" python install "${PYTHON_VERSION}"
"${UV_BIN}" sync --python "${PYTHON_VERSION}"

TMP_SERVICE="$(mktemp)"
trap 'rm -f "${TMP_SERVICE}"' EXIT

cat > "${TMP_SERVICE}" <<EOF
[Unit]
Description=RP Edge Status API
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${REPO_DIR}
SupplementaryGroups=gpio
Environment=PYTHONUNBUFFERED=1
ExecStart=${REPO_DIR}/.venv/bin/python ${REPO_DIR}/app.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

sudo install -m 644 "${TMP_SERVICE}" "${SERVICE_PATH}"
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"

if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
    sudo systemctl restart "${SERVICE_NAME}"
else
    sudo systemctl start "${SERVICE_NAME}"
fi

sudo systemctl status --no-pager "${SERVICE_NAME}"

printf '\nSetup complete.\n'
printf 'Service name: %s\n' "${SERVICE_NAME}"
printf 'Check logs with: journalctl -u %s -f\n' "${SERVICE_NAME}"

if [[ "${ADDED_GPIO_GROUP}" -eq 1 ]]; then
    printf 'The user %s was added to the gpio group. Log out and back in before running GPIO commands manually in your shell.\n' "${SERVICE_USER}"
fi
