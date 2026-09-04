# M.A.T.S. Anti-Drone System

### Mobile Autonomous Targeting System - 기동형 자율 조준 및 타겟 시스템

M.A.T.S.는 FPGA 기반의 실시간 안티드론 탐지 및 조준 시스템입니다. OV7670
카메라로 입력되는 영상을 실시간으로 처리하고, 색상 기반 분류를 통해 아군과
적군 드론을 판별합니다. 이후 VGA 화면에 경고 UI를 오버레이하고, 탐지된
타겟의 좌표 정보를 UART를 통해 PC 관제 UI로 전송합니다.

> 대한상공회의소 서울기술교육센터 온디바이스 AI 반도체 설계 1기 미니 프로젝트  
> 개발 기간: 2026.07.13 - 2026.07.21

## 결과 영상

<p align="center">
  <a href="https://youtu.be/_mGgUuENo0s?si=fW8PZqJXcjxNyCB9">
    <img src="https://img.shields.io/badge/YouTube-Watch%20Demo%20Video-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch demo video on YouTube" />
  </a>
</p>

<p align="center">
  <a href="https://youtu.be/_mGgUuENo0s?si=fW8PZqJXcjxNyCB9">
    <img src="https://img.youtube.com/vi/_mGgUuENo0s/hqdefault.jpg" alt="M.A.T.S. 결과 영상 썸네일" width="720" />
  </a>
</p>

<p align="center">
  <b>이미지 또는 YouTube 버튼을 클릭하면 시연 영상으로 이동합니다.</b>
</p>

위 영상은 카메라 입력, FPGA 영상 처리, VGA 경고 화면, PC 관제 UI가 함께
동작하는 전체 시연 결과입니다.

## 프로젝트 개요

저비용 드론을 활용한 비대칭 위협이 증가하면서, 작전 구역 안으로 접근하는
드론을 빠르게 탐지하고 대응할 수 있는 안티드론 시스템의 필요성이 커지고
있습니다.

본 프로젝트는 카메라 입력부터 객체 탐지, VGA 출력, PC 모니터링까지 이어지는
탐지 파이프라인을 FPGA 로직으로 구현하는 것을 목표로 했습니다.
단순히 소프트웨어에서 영상을 분석하는 구조가 아니라, 카메라 픽셀 스트림을
FPGA 내부 모듈들이 순차적으로 처리하도록 설계하여 실시간성을 확보하는 데
초점을 두었습니다.

주요 목표:

- 실시간 카메라 영상에서 아군 및 적군 드론 객체 탐지
- 320x240 화면을 16x12 Grid로 분할하여 안정적인 타겟 위치 산출
- Bounding Box, Warning Label, 상태 Frame을 VGA 화면에 오버레이
- UART를 통해 타겟 Type, 중심 좌표, 크기 정보를 PC UI로 전송
- 시뮬레이션 기반으로 탐지 및 UI 생성 로직 검증
- 조명 변화에 따른 오탐지를 줄이기 위해 RGB 기준 탐지 방식을 HSV 기반
  판별 방식으로 개선

## 시스템 흐름

![M.A.T.S. 데이터 흐름](img/mats-data-flow.png)

시스템은 카메라 픽셀 데이터를 하드웨어 파이프라인으로 처리합니다.
`Drone_Detector`는 색상 정보를 기반으로 타겟을 분류하고 위치를 계산합니다.
`UI_Generator`는 탐지 결과를 화면 출력용 좌표와 명령으로 변환하며,
`UI_Framebuffer`는 오버레이 픽셀을 압축 저장합니다. 마지막으로
`Frame_Generator`가 경고 프레임과 텍스트를 합성하여 VGA로 출력합니다.

전체 흐름은 크게 `CAM_Set`, `UI_Set`, `Frame_Set`, `UART_Set`으로 나뉩니다.
`CAM_Set`은 OV7670 카메라의 초기화와 픽셀 입력을 담당하고, `UI_Set`은 탐지
결과를 UI 좌표로 변환합니다. `Frame_Set`은 최종 화면의 경고 프레임과 상태
문구를 만들며, `UART_Set`은 탐지 정보를 외부 PC 프로그램으로 전달합니다.

## 디렉토리 구조

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

## 하드웨어 설계

### Drone Detector

![Drone Detector 파이프라인](img/mats-drone-detector.png)

`Drone_Detector`는 카메라에서 들어온 픽셀 데이터를 분석하여 타겟의 종류와
위치를 산출합니다. 색상 분류, Grid 기반 픽셀 카운팅, Bounding Box 계산을
거쳐 타겟 Type, 중심 좌표, Width, Height 정보를 출력합니다.

핵심 모듈:

- `Drone_Classification_Color`: 적군 및 아군 색상 영역 분류
- `Drone_pixel_counter`: 16x12 Grid 내부의 픽셀 누적 카운팅
- `Drone_posit_size`: 활성 Grid 영역 병합 및 타겟 위치와 크기 계산

### UI Generator 및 Framebuffer

`UI_Generator`는 `Drone_Detector`에서 전달받은 타겟 좌표와 크기 정보를 기반으로
점선 Bounding Box와 타겟 Label을 그리기 위한 픽셀 좌표를 생성합니다.

`UI_Framebuffer`는 전체 화면 UI 정보를 12-bit RGB로 저장하지 않고 2-bit Bitmap
형태로 압축 저장합니다. 이를 통해 BRAM 사용량을 줄이면서도 실시간 UI
오버레이를 유지할 수 있도록 설계했습니다.

### VGA 및 UART 출력

최종 화면은 카메라 원본 영상, UI 오버레이, 경고 프레임, 상태 텍스트를 합성해
VGA로 출력합니다. 동시에 UART 경로를 통해 동일한 탐지 결과를 PC 프로그램으로
전송하여 레이더 형태의 관제 UI에서 확인할 수 있도록 했습니다.

### Frame_Generator Block Diagram (담당파트)

![Frame Generator Block Diagram](img/mats-frame-generator-block.png)

`Frame_Generator`는 `UI_Generator` 이후 단계에서 최종 VGA 화면의 상태 표현을
담당합니다. 드론 탐지 결과가 적군인지 아군인지에 따라 서로 다른 프레임 색상과
상태 문구를 선택하고, 이를 픽셀 단위로 합성하여 최종 출력 화면을 완성합니다.

이 파트에서는 단순히 박스 좌표를 전달하는 것에서 끝나지 않고, 사용자가 화면을
봤을 때 즉시 상황을 판단할 수 있도록 시각적 경고 레이어를 만드는 역할을
구현했습니다.

### Frame_Generator 상세 동작 (담당파트)

![Frame Generator Detail](img/mats-frame-generator-detail.png)

담당 구현 범위:

- `Font_Rom`에 5x7 Bitmap Font 데이터를 정의하여 VGA 화면에 출력할 문자 구성
- Ally 및 Enemy Detect 신호에 따라 출력할 문구와 상태 색상 선택
- Enemy 검출 시 Red Frame과 `ENEMY DETECT !` 문구 합성
- Ally 검출 시 Green Frame과 `SAFE ZONE` 문구 합성
- 프레임 색상, 텍스트 픽셀, 기존 UI Overlay가 깨지지 않도록 VGA 타이밍에 맞춰 출력

이 모듈은 탐지 결과를 실제 사용자가 인지할 수 있는 화면 상태로 바꾸는 마지막
단계입니다. 따라서 Detector의 좌표 정보와 UI Overlay가 정상이어도
`Frame_Generator`가 정확히 동작하지 않으면 최종 경고 화면이 완성되지 않습니다.

## PC 관제 UI

![M.A.T.S. UI 설계](img/mats-ui-design.png)

PC UI는 UART로 수신한 타겟 정보를 전술 레이더 화면처럼 시각화합니다. 아군
드론, 적군 드론, 적군 근접 상황을 구분하여 표시하고 Reload, Aim, 무기 선택,
Score 표시 기능을 제공합니다.

FPGA는 VGA 화면에 직접 경고 UI를 출력하고, 동시에 UART로 동일한 탐지 정보를
PC에 전달합니다. 이 구조를 통해 현장 디스플레이와 관제 화면이 같은 탐지 결과를
공유하도록 구성했습니다.

UART Receiver는 6바이트 타겟 패킷을 복원합니다.

```text
Byte 0: {cx[1:0], type[0], eof[0], 4'b1111}
Byte 1: {cy[0], cx[8:2]}
Byte 2: {w[0], cy[7:1]}
Byte 3: {w[8:1]}
Byte 4: {h[7:0]}
Byte 5: 0xFF
```

## 검증

![UVM 검증 결과](img/mats-uvm-verification.png)

탐지 로직은 랜덤 타겟 트랜잭션을 이용해 검증했습니다. 테스트 환경에서 아군과
적군 타겟의 위치와 크기를 무작위로 생성하고, DUT가 출력한 중심 좌표, 크기,
Type 정보를 Scoreboard에서 비교했습니다.

검증에서는 입력 객체의 Type, Position, Size를 랜덤하게 변화시키고, 모니터가
DUT 출력값을 수집한 뒤 Scoreboard에서 기대값과 비교했습니다. 이를 통해 단일
케이스가 아니라 다양한 위치와 크기의 드론 객체에 대해 탐지 로직이 일관되게
동작하는지 확인했습니다.

검증 결과:

- Drone Type, Size, Position 랜덤 트랜잭션 생성
- Monitor와 Scoreboard를 통한 출력 결과 비교
- Scoreboard 결과: `pass_cnt = 100 / 100`
- 주요 Detector 데이터 필드 Coverage: `100.0%`

## 트러블슈팅

초기 탐지 방식은 고정 RGB 임계값을 사용했기 때문에 조명 변화에 따라 오탐지와
미탐지가 발생했습니다. 이를 개선하기 위해 조도와 색상 정보를 분리해서 판단할
수 있는 HSV 기반 판별 방식으로 로직을 보완했습니다.

또한 카메라 접근 임계값과 UART Sampling 주기를 조정하여 VGA 화면의 타겟
오버레이와 PC 레이더 UI의 좌표 표시가 더 안정적으로 맞도록 개선했습니다.

주요 개선 포인트:

- 조도 변화에 민감한 고정 RGB 비율 조건을 보완
- Grid 임계값을 조정하여 순간적인 노이즈가 타겟으로 인식되는 문제 완화
- UART Sampling 주기를 조정하여 PC UI 좌표 표시 지연 감소
- VGA 출력과 UI Overlay 위치가 어긋나는 문제를 모듈 간 타이밍 기준으로 정리

## 실행 방법

### Hardware

1. Vivado에서 프로젝트를 열거나 `HW_MATS/src/RTL`의 RTL 소스를 추가해 새
   프로젝트를 생성합니다.
2. `HW_MATS/constraint`의 Basys3 제약 파일을 추가합니다.
3. Synthesis 및 Implementation을 진행한 뒤 Bitstream을 생성합니다.
4. OV7670 카메라 모듈, VGA 모니터, UART USB Serial 인터페이스를 연결합니다.
5. FPGA 보드에 Bitstream을 Program합니다.

### PC UI

Python 패키지를 설치합니다.

```bash
pip install pyserial pywebview opencv-python
```

GUI 프로그램을 실행합니다.

```bash
python SW_MATS/gui_app.py --port COM5 --baud 115200
```

빌드된 실행 파일을 사용할 수도 있습니다.

```bash
SW_MATS/EXE/gui_app.exe --port COM5 --baud 115200
```

`COM5`는 Windows 장치 관리자에서 확인한 실제 Serial Port 번호에 맞게 변경합니다.

## 기술 스택

- SystemVerilog
- Xilinx Vivado
- OV7670 Camera Module
- VGA Display Pipeline
- UART Serial Communication
- Python GUI
- UVM 기반 검증 흐름
