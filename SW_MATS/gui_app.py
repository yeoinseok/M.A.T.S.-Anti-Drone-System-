import os
import sys
import time
import json
import threading
import webview
from uart_receiver import UARTReceiver

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class JSAPI:
    def __init__(self, app):
        self.app = app

    def change_camera(self, index):
        try:
            idx = int(index)
            self.app.change_camera(idx)
            return {"status": "success", "index": idx}
        except Exception as e:
            return {"status": "error", "message": str(e)}

class GUIApp:
    def __init__(self, port="COM4", baudrate=115200):
        self.window = None
        self.receiver = None
        self.push_thread = None
        self.is_running = False
        
        # 실제 UART 포트 설정 (사용자의 포트에 맞춰 COM 번호 또는 tty 경로 수정 가능)
        self.port_name = port
        self.baudrate = baudrate
        
        # 1분 노이즈 필터링용 프레임 기록 저장소
        self.frame_history = []
        
        # 동적 카메라 선택 제어 변수
        self.camera_index = 0
        self.new_camera_index = 0
        self.camera_changed = False
        self.camera_lock = threading.Lock()

    def start_uart(self):
        """UART 수신기를 초기화하고 시작합니다."""
        try:
            self.receiver = UARTReceiver(
                port=self.port_name,
                baudrate=self.baudrate
            )
            self.receiver.start()
            print(f"UART 연결 완료: {self.port_name}")
            return True
        except Exception as e:
            print(f"UART 연결 실패: {e}")
            return False

    def _push_data_loop(self):
        """UART 수신 데이터를 프레임 단위로 즉시 읽고, 1분 노이즈 필터링 후 JS로 전달합니다."""
        while self.is_running:
            try:
                if self.receiver:
                    # 완결된 최근 프레임(EOF=1로 끝나는 단위) 즉시 획득
                    frame_packets = self.receiver.get_latest_frame()
                    
                    # frame_packets가 None이면 새로운 완결 프레임이 아직 없음을 의미
                    if frame_packets is not None:
                        now = time.time()
                        
                        # 터미널 콘솔에는 수신된 모든 원본 패킷을 즉시 출력하여 수신 상태 표시
                        from datetime import datetime
                        timestamp_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
                        for pkt in frame_packets:
                            clean_pkt = {k: v for k, v in pkt.items() if not k.startswith('_')}
                            print(f"파싱 결과 딕셔너리: {clean_pkt} [{timestamp_str}]")
                        
                        # eof가 1이 아닌 패킷만 실제 타겟 데이터로 간주 (eof=1인 패킷의 다른 데이터는 무시)
                        targets_in_frame = [p for p in frame_packets if p.get('eof') != 1]
                        
                        # 프레임 기록(현재 시간, 타겟들) 저장
                        self.frame_history.append((now, targets_in_frame))
                        
                        # 1.0초 이전의 오래된 프레임 기록 제거 (1초 슬라이딩 윈도우)
                        self.frame_history = [(t, pkts) for t, pkts in self.frame_history if now - t <= 1.0]
                        
                        N = len(self.frame_history) # 1초 내 총 수신 프레임 수
                        
                        # 각 타입별(0: 적군, 1: 우군) 1초 내 검출 프레임 수 계산
                        enemy_detected_frames = sum(1 for t, pkts in self.frame_history if any(p.get('type') == 0 for p in pkts))
                        friendly_detected_frames = sum(1 for t, pkts in self.frame_history if any(p.get('type') == 1 for p in pkts))
                        
                        clean_packets = []
                        
                        # 현재 프레임의 타겟들에 대해 상태 판단 (1초 기준 3회 이상 감지되면 다수 인식, 2회 이하면 단발성)
                        for pkt in targets_in_frame:
                            t_type = pkt.get('type')
                            D = enemy_detected_frames if t_type == 0 else friendly_detected_frames
                            
                            # 1초 내 4회 이상 검출 시 다수 인식(stable=1), 2회 이하 검출 시 단발성 인식(stable=0)
                            is_stable = 1 if D >= 4 else 0
                            
                            clean_pkt = {k: v for k, v in pkt.items() if not k.startswith('_')}
                            clean_pkt['stable'] = is_stable
                            clean_packets.append(clean_pkt)
                        
                        # eof=1인 동기화 신호 패킷은 노이즈 필터링과 무관하게 화면 갱신/지우기용으로 원본 구조만 전송
                        for p in frame_packets:
                            if p.get('eof') == 1:
                                clean_pkt = {k: v for k, v in p.items() if not k.startswith('_')}
                                # 타겟 그리기에 사용되지 않도록 확인
                                if not any(cp.get('eof') == 1 for cp in clean_packets):
                                    clean_packets.append(clean_pkt)
                            
                        if self.window:
                            self.safe_evaluate_js(f"updateDataList({json.dumps(clean_packets)})")
                
                time.sleep(0.001)  # 1ms 주기로 완결 프레임을 즉시 획득하여 실시간 반응
            except Exception as e:
                print(f"데이터 전송 루프 에러: {e}")
                time.sleep(0.01)

    def change_camera(self, index):
        """카메라 인덱스를 동적으로 변경합니다."""
        with self.camera_lock:
            self.new_camera_index = index
            self.camera_changed = True
        print(f"카메라 변경 요청: CAM {index}")

    def _camera_loop(self):
        """웹캠에서 영상을 캡처하여 base64 이미지로 UI에 전송합니다."""
        import cv2
        import base64

        cap = None
        current_index = -1

        while self.is_running:
            # 카메라 변경 여부 확인
            with self.camera_lock:
                if self.camera_changed or cap is None:
                    if cap is not None and cap != "FAILED":
                        cap.release()
                    
                    # 이미 실패 상태이고 카메라 변경 요청이 없으면 루프 대기
                    if not self.camera_changed and cap == "FAILED":
                        time.sleep(0.5)
                        continue

                    current_index = self.new_camera_index
                    self.camera_index = current_index
                    self.camera_changed = False
                    
                    print(f"카메라 {current_index} 연결 시도 중...")
                    cap = cv2.VideoCapture(current_index)
                    
                    if not cap.isOpened():
                        print(f"Warning: 카메라 {current_index}을 열 수 없습니다. (대기 모드 진입)")
                        self.safe_evaluate_js("updateCameraFrame(null)")
                        cap.release()
                        cap = "FAILED"
                        continue
                    else:
                        print(f"카메라 {current_index} 연결 성공")

            # 실패 상태이면 대기
            if cap == "FAILED":
                time.sleep(0.5)
                continue

            try:
                ret, frame = cap.read()
                if not ret:
                    time.sleep(0.03)
                    continue

                # 화면 전송 부하를 줄이기 위해 크기를 4:3 비율(320x240)로 축소
                small_frame = cv2.resize(frame, (320, 240))
                
                # JPEG로 압축
                _, buffer = cv2.imencode('.jpg', small_frame, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
                
                # Base64 인코딩
                b64_data = base64.b64encode(buffer).decode('utf-8')
                
                # JS 함수 호출
                self.safe_evaluate_js(f"updateCameraFrame('{b64_data}')")
            except Exception as e:
                print(f"카메라 스트리밍 에러: {e}")
                time.sleep(0.1)
                
            time.sleep(0.033) # 약 30 FPS 유지

        if cap is not None and cap != "FAILED":
            cap.release()

    def safe_evaluate_js(self, js_code):
        """WebView가 종료되는 시점에 evaluate_js 호출 시 발생하는 예외를 안전하게 잡아줍니다."""
        try:
            if self.window and self.is_running:
                self.window.evaluate_js(js_code)
        except Exception:
            pass

    def run(self):
        # 1. UART 수신기 시동
        self.start_uart()

        # 2. HTML 파일 경로 획득
        html_path = resource_path(os.path.join('web', 'index.html'))
        
        # 3. WebView 창 생성
        self.api = JSAPI(self)
        self.window = webview.create_window(
            title="M.A.T.S. - Tactical Object Tracker",
            url=html_path,
            width=1150,
            height=780,
            resizable=True,
            background_color='#030708',
            js_api=self.api
        )

        # 4. 백그라운드 스레드 시동
        self.is_running = True
        self.push_thread = threading.Thread(target=self._push_data_loop, daemon=True)
        self.camera_thread = threading.Thread(target=self._camera_loop, daemon=True)
        
        def on_shown():
            time.sleep(0.5)  # WebView 초기화 대기
            self.push_thread.start()
            self.camera_thread.start()

        self.window.events.shown += on_shown

        # 5. GUI 시작
        webview.start()

        # 6. 종료 처리
        self.is_running = False
        if self.receiver:
            self.receiver.stop()

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="M.A.T.S. - Tactical Object Tracker")
    parser.add_argument('--port', '-p', type=str, default='COM4', help='UART COM Port (default: COM4)')
    parser.add_argument('--baud', '-b', type=int, default=115200, help='UART Baudrate (default: 115200)')
    args, unknown = parser.parse_known_args()

    app = GUIApp(port=args.port, baudrate=args.baud)
    app.run()
