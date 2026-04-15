from datetime import datetime, timezone
from threading import Lock

from flask import Flask, jsonify

# Edit these values for each Raspberry Pi.
HOST = "0.0.0.0"
PORT = 8000
DEVICE_NAME = "edge-1"

LED_COMMON_ANODE = False
RED_PIN = 17
GREEN_PIN = 27
BLUE_PIN = 22

STATE_TO_COLOR = {
    "on": ("green", (0, 1, 0)),
    "idle": ("blue", (0, 0, 1)),
    "off": ("red", (1, 0, 0)),
}

app = Flask(__name__)
state_lock = Lock()
current_state = "idle"
last_changed_at = ""
led = None


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def setup_led():
    global led

    try:
        from gpiozero import RGBLED
    except ImportError as exc:
        raise RuntimeError("Install gpiozero before running the service") from exc

    led = RGBLED(
        red=RED_PIN,
        green=GREEN_PIN,
        blue=BLUE_PIN,
        active_high=not LED_COMMON_ANODE,
    )


def apply_led(state):
    if led is None:
        return

    _, rgb = STATE_TO_COLOR[state]
    led.color = rgb


def make_status(changed=None):
    color, _ = STATE_TO_COLOR[current_state]

    payload = {
        "device": DEVICE_NAME,
        "state": current_state,
        "color": color,
        "last_changed_at": last_changed_at,
    }

    if changed is not None:
        payload["changed"] = changed

    return payload


@app.after_request
def disable_cache(response):
    response.headers["Cache-Control"] = "no-store"
    return response


@app.get("/healthz")
def healthz():
    return jsonify({"ok": True, "device": DEVICE_NAME})


@app.get("/status")
def get_status():
    with state_lock:
        return jsonify(make_status())


@app.get("/status/<requested_state>")
def set_status(requested_state):
    global current_state, last_changed_at

    if requested_state not in STATE_TO_COLOR:
        return (
            jsonify(
                {
                    "error": "invalid state",
                    "allowed_states": list(STATE_TO_COLOR.keys()),
                }
            ),
            400,
        )

    with state_lock:
        if requested_state == current_state:
            return jsonify(make_status(changed=False))

        try:
            apply_led(requested_state)
        except Exception as exc:
            return jsonify({"error": str(exc)}), 500

        current_state = requested_state
        last_changed_at = now_iso()
        return jsonify(make_status(changed=True))


if __name__ == "__main__":
    last_changed_at = now_iso()
    setup_led()
    apply_led(current_state)
    app.run(host=HOST, port=PORT)
