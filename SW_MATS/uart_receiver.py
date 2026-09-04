import serial
import threading
import time
import logging
import json
from datetime import datetime
from typing import Dict, Any, Optional

# 로깅 설정
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("UARTReceiver")

class UARTReceiver:
    """
    UART 통신을 통해 5바이트(35비트 데이터 + 5비트 패딩)의 패킷을 수신하고,
    비트 슬라이싱하여 딕셔너리 형태로 저장 및 관리하는 클래스
    """
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.packet_size = 6  # 6바이트 시퀀스: {0x?F, cx_lsb, cy, w_lsb, h, 0xFF}
        
        self.serial_conn: Optional[serial.Serial] = None
        self.is_running = False
        self.read_thread: Optional[threading.Thread] = None
        
        # 수신된 데이터 저장용
        self.latest_data: Dict[str, Any] = {}
        self.data_history = []
        self.data_lock = threading.Lock()

    @staticmethod
    def parse_bits(raw_bytes: bytes) -> Dict[str, Any]:
        """
        6바이트 바이너리 패킷을 파싱합니다 (Verilog 스타일 비트 패킹).
        비트 매핑 스펙:
        - Byte 0: {cx[1:0], type[0], eof[0], 4'b1111}
        - Byte 1: {cy[0], cx[8:2]}
        - Byte 2: {w[0], cy[7:1]}
        - Byte 3: {w[8:1]}
        - Byte 4: {h[7:0]}
        - Byte 5: 8'hFF
        """
        if len(raw_bytes) < 6:
            return {}
        
        b0 = raw_bytes[0]
        b5 = raw_bytes[5]
        
        # 시작 니블(하위 4비트 0x0F) 및 테일(0xFF) 검증
        if (b0 & 0x0F) != 0x0F or b5 != 0xFF:
            return {}
        
        # Byte 0 디코딩
        cx_1_0 = (b0 >> 6) & 0x03
        type_val = (b0 >> 5) & 0x01
        eof = (b0 >> 4) & 0x01
        
        # Byte 1 디코딩
        cy_0 = (raw_bytes[1] >> 7) & 0x01
        cx_8_2 = raw_bytes[1] & 0x7F
        
        # Byte 2 디코딩
        w_0 = (raw_bytes[2] >> 7) & 0x01
        cy_7_1 = raw_bytes[2] & 0x7F
        
        # Byte 3 디코딩
        w_8_1 = raw_bytes[3]
        
        # 데이터 복원
        cx = (cx_8_2 << 2) | cx_1_0
        cy = (cy_7_1 << 1) | cy_0
        w = (w_8_1 << 1) | w_0
        h = raw_bytes[4]
        
        return {
            "eof": eof,
            "type": type_val,
            "cx": cx,
            "cy": cy,
            "w": w,
            "h": h
        }

    def start(self):
        """UART 수신 스레드를 시작합니다."""
        if self.is_running:
            return

        try:
            self.serial_conn = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=self.timeout
            )
            logger.info(f"UART 연결 완료: {self.port} (Baudrate: {self.baudrate})")
        except serial.SerialException as e:
            logger.error(f"UART 연결 실패: {e}")
            raise

        self.is_running = True
        self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
        self.read_thread.start()

    def stop(self):
        """UART 수신 스레드를 중지하고 포트를 닫습니다."""
        self.is_running = False
        if self.read_thread:
            self.read_thread.join(timeout=2.0)
            
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()
            logger.info("UART 포트가 닫혔습니다.")

    def _read_loop(self):
        """실시간 바이트 스트림에서 6바이트 시퀀스 프레임 동기화를 맞추어 수신하는 루프"""
        buffer = bytearray()
        
        while self.is_running:
            if not self.serial_conn or not self.serial_conn.is_open:
                time.sleep(0.1)
                continue
            
            try:
                if self.serial_conn.in_waiting > 0:
                    # 1바이트씩 스트림을 읽어 버퍼에 추가
                    b = self.serial_conn.read(1)[0]
                    buffer.append(b)
                    
                    # 버퍼에 6바이트 이상 쌓인 경우 슬라이딩 매칭 시도
                    while len(buffer) >= 6:
                        # 첫 바이트가 0x?F (하위 4비트가 0x0F)이고 6번째 바이트가 0xFF인지 확인
                        if (buffer[0] & 0x0F) == 0x0F and buffer[5] == 0xFF:
                            # 6바이트 패킷 동기화 시작점과 끝점이 정확히 정렬된 경우 패킷 분리
                            packet_bytes = bytes(buffer[:6])
                            del buffer[:6]
                            
                            # 데이터 파싱 처리
                            parsed_dict = self.parse_bits(packet_bytes)
                            if parsed_dict:
                                parsed_dict['_timestamp'] = time.time()
                                with self.data_lock:
                                    self.latest_data = parsed_dict
                                    self.data_history.append(parsed_dict)
                                    if len(self.data_history) > 1000:
                                        self.data_history.pop(0)
                            break
                        else:
                            # 동기화 정합성이 맞지 않으면 맨 앞 1바이트를 버리고 계속 슬라이딩 검사
                            buffer.pop(0)
            except Exception as e:
                logger.error(f"수신 에러: {e}")
                time.sleep(0.1)
            
            time.sleep(0.001)

    def get_latest_data(self) -> Dict[str, Any]:
        """가장 최근에 수신된 데이터의 복사본을 반환합니다."""
        with self.data_lock:
            return self.latest_data.copy()

    def get_latest_frame(self) -> list[Dict[str, Any]]:
        """
        수신 기록(history)에서 가장 최근에 완성된 프레임(EOF=1로 끝나는 시퀀스)을 추출하고,
        그 이전의 오래된 데이터는 기록에서 삭제(버림)합니다.
        """
        with self.data_lock:
            if not self.data_history:
                return []
            
            # 뒤에서부터 탐색하여 eof == 1인 가장 최근 패킷의 인덱스를 찾음
            last_eof_idx = -1
            for i in range(len(self.data_history) - 1, -1, -1):
                if self.data_history[i].get("eof") == 1:
                    last_eof_idx = i
                    break
            
            if last_eof_idx == -1:
                return []
            
            # eof == 1인 지점부터 앞으로 가면서 그 직전 eof == 1을 만나기 전까지의 모든 패킷을 한 프레임으로 수집
            frame_packets = []
            for i in range(last_eof_idx, -1, -1):
                packet = self.data_history[i]
                if i < last_eof_idx and packet.get("eof") == 1:
                    break
                frame_packets.insert(0, packet.copy())
            
            # 수집 완료 후, 수집된 프레임 끝(last_eof_idx)을 포함하여 그 이전의 모든 데이터 삭제
            del self.data_history[:last_eof_idx + 1]
            
            return frame_packets

    def get_history(self):
        """수신 기록을 반환합니다."""
        with self.data_lock:
            return list(self.data_history)

if __name__ == "__main__":

    # --- 실제 COM4 포트 실시간 수신 구동부 ---
    PORT_NAME = "COM13"
    BAUD_RATE = 115200
    OUTPUT_FILE = "uart_data.txt"

    print(f"=== 실제 UART 실시간 수신 및 파일 저장 시작 ({PORT_NAME}, {BAUD_RATE}) ===")
    print(f"로그 저장 파일: {OUTPUT_FILE}")
    receiver = UARTReceiver(port=PORT_NAME, baudrate=BAUD_RATE)

    try:
        receiver.start()
        print("장치 데이터 수신 대기 중... (Ctrl+C로 종료)\n")
        
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            while True:
                time.sleep(0.01)  # 10ms 단위로 버퍼 확인
                
                # 수신 큐(history)에서 쌓인 모든 데이터를 가져와 비우기
                packets = []
                with receiver.data_lock:
                    if receiver.data_history:
                        packets = list(receiver.data_history)
                        receiver.data_history.clear()
                
                # 수신된 순서대로 누락 없이 출력 및 파일 저장
                for pkt in packets:
                    clean_data = {k: v for k, v in pkt.items() if not k.startswith('_')}
                    timestamp_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
                    print(f"파싱 결과 딕셔너리: {clean_data} [{timestamp_str}]")
                    
                    # 파일에 한 줄씩 JSON 문자열로 저장
                    f.write(json.dumps(clean_data, ensure_ascii=False) + "\n")
                    f.flush()  # 즉시 파일에 쓰도록 플러시
    except KeyboardInterrupt:
        print("\nUART 수신을 종료합니다.")
    finally:
        receiver.stop()
