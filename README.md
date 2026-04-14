# rp-edge-status

Tiny HTTP service for a Raspberry Pi status LED.

## Quickstart

On a Raspberry Pi, start or refresh the service with:

```bash
bash setup-pi.sh
```

To stop the service:

```bash
sudo systemctl stop rp-edge-status
```

## Run

```bash
uv sync
uv run python app.py
```

The service listens on `0.0.0.0:8000` by default.

## Endpoints

- `GET /healthz`
- `GET /status`
- `GET /status/on` -> Green
- `GET /status/idle` -> Blue
- `GET /status/off` -> Red

Example response:

```json
{
  "device": "edge-1",
  "state": "idle",
  "color": "blue",
  "last_changed_at": "2026-04-14T10:00:00+00:00",
  "changed": true
}
```

## Per-Pi Settings

Edit the constants at the top of `app.py`:

- `DEVICE_NAME`
- `HOST`
- `PORT`
- `USE_GPIO`
- `LED_COMMON_ANODE`
- `RED_PIN`
- `GREEN_PIN`
- `BLUE_PIN`

## GPIO Note

The code already has the GPIO hook built in, but it is off by default with `USE_GPIO = False`.

When you are ready to use the real RGB LED on the Pi:

1. Set `USE_GPIO = True`.
2. Set the correct GPIO pins in `app.py`.
3. Run `uv sync` on the Pi.

## Pi Setup Script

After cloning on a Raspberry Pi, you can do the whole setup with one command:

```bash
bash setup-pi.sh
```

What it does:

- installs `uv` if it is missing
- installs Python `3.12` with `uv`
- creates the project `.venv` with Python `3.12`
- installs the Python dependencies
- installs a `systemd` service named `rp-edge-status`
- enables the service on boot
- starts or restarts the service immediately

Notes:

- run the script as your normal Pi user, not as `root`
- the script will ask for `sudo` because it installs the `systemd` service
- edit the constants in `app.py` first if you need a different `DEVICE_NAME`, port, or GPIO pins

## Managing the Service

If the config in `app.py` is wrong:

1. Edit `app.py`.
2. Rerun the setup script:

```bash
bash setup-pi.sh
```

That is the only command you need for both first-time setup and later refreshes. It will resync the environment, rewrite the service file, and start the service again.

Because the app keeps state in memory only, rerunning the setup also resets the current status back to the default in `app.py`.

To stop the service:

```bash
sudo systemctl stop rp-edge-status
```

To inspect the current service state:

```bash
sudo systemctl status rp-edge-status
journalctl -u rp-edge-status -f
```
