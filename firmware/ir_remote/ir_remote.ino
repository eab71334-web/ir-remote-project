// ESP32 IR learner/sender over BLE
// Library needed: IRremoteESP8266 (Arduino Library Manager)
#include <Arduino.h>
#include <IRremoteESP8266.h>
#include <IRrecv.h>
#include <IRsend.h>
#include <IRutils.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define RECV_PIN 15   // TSOP38238 OUT
#define SEND_PIN 4    // IR LED (via transistor)
#define SVC_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define RX_UUID  "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  // app -> esp (write)
#define TX_UUID  "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  // esp -> app (notify)

IRrecv irrecv(RECV_PIN, 1024, 15, true);
IRsend irsend(SEND_PIN);
decode_results results;
BLECharacteristic *tx;
volatile bool learning = false;

class RxCb : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) {
    auto raw = c->getValue();
    String s = String(raw.c_str());
    if (s == "L") { learning = true; return; }
    if (s.startsWith("S:")) {               // S:<type>:<hexvalue>:<bits>
      int a = s.indexOf(':', 2), b = s.indexOf(':', a + 1);
      int type = s.substring(2, a).toInt();
      uint64_t val = strtoull(s.substring(a + 1, b).c_str(), NULL, 16);
      uint16_t bits = s.substring(b + 1).toInt();
      irsend.send((decode_type_t)type, val, bits);
    }
  }
};

class SrvCb : public BLEServerCallbacks {
  void onDisconnect(BLEServer *s) { BLEDevice::startAdvertising(); }
};

void setup() {
  irsend.begin();
  irrecv.enableIRIn();
  BLEDevice::init("IR-Remote");
  BLEServer *srv = BLEDevice::createServer();
  srv->setCallbacks(new SrvCb());
  BLEService *svc = srv->createService(SVC_UUID);
  tx = svc->createCharacteristic(TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  tx->addDescriptor(new BLE2902());
  BLECharacteristic *rx = svc->createCharacteristic(RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  rx->setCallbacks(new RxCb());
  svc->start();
  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SVC_UUID);
  adv->start();
}

void loop() {
  if (irrecv.decode(&results)) {
    if (learning && results.decode_type != decode_type_t::UNKNOWN) {
      char buf[48];
      snprintf(buf, sizeof(buf), "R:%d:%llX:%d", (int)results.decode_type,
               (unsigned long long)results.value, results.bits);
      tx->setValue((uint8_t *)buf, strlen(buf));
      tx->notify();
      learning = false;
    }
    irrecv.resume();
  }
  delay(10);
}
