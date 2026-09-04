# M.A.T.S. Anti-Drone System

### Mobile Autonomous Targeting System

M.A.T.S. is an FPGA-based real-time anti-drone detection and targeting system.
It receives live OV7670 camera input, classifies ally and enemy targets through
color-based image processing, renders a VGA warning overlay, and sends target
coordinates to a PC monitoring UI over UART.

> 대한상공회의소 서울기술교육센터 온디바이스 AI 반도체 설계 1기 미니 프로젝트  
> Development period: 2026.07.13 - 2026.07.21

![M.A.T.S. demo result](img/mats-demo-result.png)

## Overview

Modern low-cost drones have increased the need for compact anti-drone systems
that can detect targets close to the operating area and support fast response.
This project implements the target detection pipeline on FPGA logic, from camera
capture to real-time display overlay and external monitoring.

Core goals:

- Detect ally and enemy drone objects from live camera input
- Split the 320x240 frame into a 16x12 grid for stable target localization
- Generate bounding boxes, warning labels, and frame overlays on VGA output
- Transmit target type, center position, and size to the PC UI through UART
- Verify the target detection and UI generation logic with simulation

## System Flow

![M.A.T.S. data flow](img/mats-data-flow.png)

The system processes camera pixels through a hardware pipeline. `Drone_Detector`
classifies target color and calculates object position. `UI_Generator` converts
target information into drawing instructions. `UI_Framebuffer` stores compressed
overlay pixels, and `Frame_Generator` adds the final warning frame and text before
VGA output.

## Repository Structure

```text
.
+-- HW_MATS/
|   +-- src/RTL/
|   |   +-- CAM_Set/
|   |   +-- UI_Set/
|   |   +-- Frame_Set/
|   |   +-- UART_Set/
|   |   +-- TOP_sys.sv
|   |   +-- VGA_Decoder.sv
|   +-- sim/
|   +-- constraint/
+-- SW_MATS/
    +-- gui_app.py
    +-- uart_receiver.py
    +-- web/index.html
```

## Hardware Design

### Drone Detector

![Drone detector pipeline](img/mats-drone-detector.png)

`Drone_Detector` identifies target type and position from camera pixel data.
The detector uses color classification, grid-based pixel counting, and bounding
box calculation to output target type, center coordinates, width, and height.

Key modules:

- `Drone_Classification_Color`: classifies enemy and ally color regions
- `Drone_pixel_counter`: accumulates pixels inside the 16x12 grid
- `Drone_posit_size`: merges active grid regions and calculates target geometry

### UI Generator and Framebuffer

`UI_Generator` receives target geometry from the detector and generates the
pixel coordinates required for dashed bounding boxes and target labels.
`UI_Framebuffer` stores overlay data in a compact 2-bit bitmap format instead of
full 12-bit RGB, reducing BRAM usage while preserving real-time rendering.

### VGA and UART Output

The final screen combines camera pixels, UI overlay pixels, warning frames, and
text labels. The UART path sends target information to the PC application so the
same detection result can appear in the radar-style monitoring UI.

## PC Monitoring UI

![M.A.T.S. UI design](img/mats-ui-design.png)

The PC UI visualizes the target stream as a tactical radar display. It separates
ally, enemy, and critical approach scenarios, and supports monitoring functions
such as reload, aim mode, weapon selection, and score tracking.

The UART receiver decodes a 6-byte target packet:

```text
Byte 0: {cx[1:0], type[0], eof[0], 4'b1111}
Byte 1: {cy[0], cx[8:2]}
Byte 2: {w[0], cy[7:1]}
Byte 3: {w[8:1]}
Byte 4: {h[7:0]}
Byte 5: 0xFF
```

## Verification

![UVM verification result](img/mats-uvm-verification.png)

The detection logic was verified with randomized target transactions. The test
environment generated ally and enemy targets with random positions and sizes,
then compared the detected center coordinates, size, and type through a
scoreboard.

Verification highlights:

- Randomized drone type, size, and position transactions
- Monitor and scoreboard comparison for detector output
- Scoreboard result: `pass_cnt = 100 / 100`
- Coverage result: `100.0%` for major detector data fields

## Troubleshooting

During testing, fixed RGB thresholding caused false detection under changing
lighting. The detection logic was improved by moving toward an HSV-style color
decision model, which separates brightness from color information and improves
ally/enemy classification stability.

The team also tuned camera thresholds and UART sampling timing to align the VGA
target overlay with the PC radar display.

## Quick Start

### Hardware

1. Open the Vivado project or create a new project with the RTL sources in
   `HW_MATS/src/RTL`.
2. Add the Basys3 constraint file from `HW_MATS/constraint`.
3. Generate the bitstream.
4. Connect the OV7670 camera module, VGA monitor, and UART USB serial interface.
5. Program the FPGA board.

### PC UI

Install Python dependencies:

```bash
pip install pyserial pywebview opencv-python
```

Run the GUI application:

```bash
python SW_MATS/gui_app.py --port COM5 --baud 115200
```

For the packaged executable:

```bash
SW_MATS/EXE/gui_app.exe --port COM5 --baud 115200
```

Change `COM5` to the serial port assigned by Windows Device Manager.

## Tech Stack

- SystemVerilog
- Xilinx Vivado
- OV7670 camera module
- VGA display pipeline
- UART serial communication
- Python GUI
- UVM-style verification flow
