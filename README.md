# rp-edge-status

Tiny HTTP service for a Raspberry Pi status LED.

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
