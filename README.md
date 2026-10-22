# IR Remote (ESP32 + Flutter)

## Wiring
- TSOP38238: OUT -> GPIO15, VCC -> 3.3V, GND -> GND
- IR LED: GPIO4 -> 1k resistor -> NPN base (2N2222); LED + 100 ohm from 5V to collector; emitter -> GND

## Firmware
Arduino IDE -> install "IRremoteESP8266" -> open firmware/ir_remote/ir_remote.ino -> upload to ESP32.

## App
Push to GitHub -> Actions tab -> download app-apk / app-ipa artifacts.
IPA is unsigned: install with AltStore or Sideloadly.

## Use
Bluetooth icon -> connect. "+" -> name the button -> point receiver remote at the TSOP and press the button.
Tap a button to send. Long-press to delete.
