# Smart-environmental-monitoring-system -> FPGA Sensor Processing Pipeline – README

## Project Overview

This project implements a complete FPGA-based data processing pipeline for environmental monitoring. Sensor data (Air Quality Index, Temperature, and Light Intensity) is acquired by an Arduino, transmitted to the FPGA via UART, processed through multiple digital stages, and used to generate trend, anomaly, and control signals.

The design is fully modular, allowing each processing stage to be tested independently and then integrated into a final top-level module.

---

## Data Flow Summary

1. Arduino reads analog sensors and converts them to digital values.
2. Sensor values are formatted into ASCII packets and sent via UART.
3. FPGA receives and decodes the packet.
4. Data is filtered to reduce noise.
5. Trend and anomaly detection is applied.
6. Temperature data is processed by a PID controller for control purposes.
7. Status outputs are displayed using LEDs.

---

## Packet Format

Sensor data is transmitted using the following ASCII format:

```
#A:xxx#T:xxx#L:xxx#
```

Where:

* `A` = Air Quality Index
* `T` = Temperature
* `L` = Light Intensity
* `xxx` = decimal ASCII digits

---

## Implemented Modules

### UART Receiver

Receives serial data from the Arduino and outputs individual ASCII characters with a data-valid signal.

### Packet FSM Decoder

Parses the incoming ASCII stream, detects packet structure, converts ASCII digits to binary values, and outputs parallel AQI, temperature, and light measurements.

### Moving Average Filter

Applies a sliding-window average to smooth sensor noise before further processing.

### Trend Detector

Compares consecutive filtered samples and classifies the signal as:

* steady
* rising
* falling
  Also generates spike alerts for sudden changes.

### Z-Score Anomaly Detector

Detects statistical anomalies by comparing the current value against a mean and standard deviation. Flags abnormal sensor behavior.

### PID Controller

Uses filtered temperature data to compute a control signal using proportional, integral, and derivative terms. Designed for fixed-point arithmetic.

### Final_Top

Integrates all modules into a single pipeline and exposes system-level outputs:

* anomaly flags
* temperature trend

---

## Testing Methodology

Each module was tested independently using dedicated testbenches:

* UART TX/RX testbench
* FSM Decoder testbench
* Moving Average Filter testbench
* Trend Detector testbench
* Z-Score Anomaly Detector testbench
* PID Controller testbench

After standalone verification, the modules were integrated and tested in the `Final_Top` design. System-level testbenches focused on feeding realistic input data and observing correct propagation through the pipeline.

This modular testing approach simplified debugging and ensured correctness at each stage.

---

## Hardware Platform

* Boards: Basys3 and UNO Minima R4 WiFi
* Clock: 100 MHz
* UART: USB-UART interface
* Outputs: LEDs for anomaly and trend indication
* Sensors: LDR, Gas Sensor, Temperature Sensor
* Other: Level Shifter

---

## How to Use

1. Program the FPGA with the `Final_Top` design.
2. Connect the Arduino UART TX to the FPGA UART RX pin.
3. Send properly formatted packets from the Arduino.
4. Observe anomaly flags and trend indicators on LEDs.

---

## Notes

* PWM output is not included in the final top module (PID output is computed but not driven externally).
* Mean and standard deviation inputs for Z-score detection are currently static and can be extended dynamically.

---


