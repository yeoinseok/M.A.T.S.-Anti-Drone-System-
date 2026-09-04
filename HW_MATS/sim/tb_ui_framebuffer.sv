// `timescale 1ns / 1ps

// module tb_ui_framebuffer;

//     // 시스템 및 해상도 파라미터 정의
//     localparam int WIDTH = 320;
//     localparam int HEIGHT = 240;
//     localparam int ADDR_W = $clog2(WIDTH * HEIGHT);

//     // 하드웨어 타이밍 정합성을 위한 100MHz 동기 클록 주기 (10ns)
//     localparam real WRITE_CLK_PERIOD = 10.00;
//     localparam real READ_CLK_PERIOD = 41.00;

//     // 공통 및 쓰기(카메라) 도메인 신호 선언
//     logic write_clk, read_clk, reset;
//     logic ready, done;
//     logic valid, target_type;
//     logic [8:0] box_x;
//     logic [7:0] box_y;

//     // 읽기(디스플레이) 도메인 신호 선언
//     logic [9:0] x_pixel, y_pixel;
//     logic de;
//     logic [11:0] i_camera_rgb; // 원본 카메라 입력 (배경 투명도 검증용)

//     logic [11:0] i_camera_rgb_d1, i_camera_rgb_d2;
//     logic [9:0] x_px_d1, x_px_d2;
//     logic [9:0] y_px_d1, y_px_d2;
//     logic de_d1, de_d2;

//     logic [11:0] expected_rgb_val;

//     // BRAM 판독 지연과 SCREEN_MUX 조합 회로 타이밍을 추적하기 위해 2사이클 파이프라인 매칭 지연 적용
//     always_ff @(posedge read_clk) begin
//         i_camera_rgb_d1 <= i_camera_rgb;
//         i_camera_rgb_d2 <= i_camera_rgb_d1;
//         de_d1           <= de;
//         de_d2           <= de_d1;
//         x_px_d1         <= x_pixel;
//         x_px_d2         <= x_px_d1;
//         y_px_d1         <= y_pixel;
//         y_px_d2         <= y_px_d1;
//     end

//     // 내부 모듈 간 상호 연결 와이어 선언
//     logic [1:0] w_bitmap_pixel;

//     // 최종 검증 대상 출력 신호 (12비트 합성 RGB)
//     logic [11:0] o_screen_rgb;

//     // 로그 파일 식별 변수
//     int log_file;

//     // =========================================================
//     // 1. 모듈 통합 인스턴스화 (DUT 환경 구축)
//     // =========================================================

//     // UI 프레임버퍼 (하부에 내부적으로 bitmap_bram을 포함하여 구동됨)
//     ui_framebuffer #(
//         .WIDTH (WIDTH),
//         .HEIGHT(HEIGHT),
//         .ADDR_W(ADDR_W)
//     ) u_framebuffer (
//         .write_clk   (write_clk),
//         .read_clk    (read_clk),
//         .reset       (reset),
//         .ready       (ready),
//         .done        (done),
//         .valid       (valid),
//         .target_type (target_type),
//         .box_x       (box_x),
//         .box_y       (box_y),
//         .x_pixel     (x_pixel),
//         .y_pixel     (y_pixel),
//         .de          (de),
//         .bitmap_pixel(w_bitmap_pixel)  // 포트 B 판독 인덱스 출력
//     );

//     // 최종 단 합성 멀티플렉서 (SCREEN_MUX)
//     SCREEN_MUX u_screen_mux (
//         .ui_enable(1'b1),  // UI 표시 기능 마스터 활성화
//         .i_camera_rgb(i_camera_rgb_d2),  // 원본 배경 입력
//         .i_bitmap_pixel (w_bitmap_pixel),  // 버퍼가 뿜어내는 2비트 인덱스 수신
//         .o_screen_rgb(o_screen_rgb)  // 최종 12비트 출력 관측 대상
//     );

//     // 클록 생성 엔진
//     initial begin
//         write_clk = 0;
//         forever #(WRITE_CLK_PERIOD / 2.0) write_clk = ~write_clk;
//     end
//     initial begin
//         read_clk = 0;
//         forever #(READ_CLK_PERIOD / 2.0) read_clk = ~read_clk;
//     end

//     // =========================================================
//     // 스코어보드 (Scoreboard) - 12비트 최종 RGB 기대치 역추적용 메모리
//     // =========================================================
//     logic [11:0] expected_rgb[0:WIDTH-1][0:HEIGHT-1];

//     // 읽기 도메인 주사 시 자동 소거 타이밍(x[0]&&y[0])에 맞춰 정답지도 투명(UI_NONE)으로 동기화 초기화
//     always_ff @(posedge read_clk) begin
//         if (de_d2 && x_px_d2[0] && y_px_d2[0]) begin
//             expected_rgb[x_px_d2/2][y_px_d2/2] <= 12'hAAA; // 기본 카메라 데이터(배경) 복원 기대치
//         end
//     end

//     // =========================================================
//     // Task: 유효 픽셀 데이터 주입 (Write Protocol)
//     // =========================================================
//     task automatic write_ui_pixel(input logic t_type, input logic [8:0] x,
//                                   input logic [7:0] y);
//         begin
//             while (!ready)
//             @(posedge write_clk);  // 버퍼 FSM 준비 상태 확인 대기

//             valid              <= 1'b1;
//             target_type        <= t_type;
//             box_x              <= x;
//             box_y              <= y;

//             // 최종 12비트 RGB 정답 예측 테이블 설정 (적군: RED=12'hF00 / 아군: GREEN=12'h0F0)
//             expected_rgb[x][y] <= t_type ? 12'h0F0 : 12'hF00;

//             @(posedge write_clk);
//             valid       <= 1'b0;
//             target_type <= 1'b0;
//             box_x       <= '0;
//             box_y       <= '0;

//             while (!done)
//             @(posedge write_clk);  // 내부 BRAM 적재 완료 확인 대기
//             @(posedge write_clk);
//         end
//     endtask

//     // =========================================================
//     // [추가] Task: 네모 박스 테두리 좌표 순차 주입 (Box Outline Protocol)
//     // =========================================================
//     task automatic write_ui_box(
//         input logic t_type,
//         input logic [8:0] x1, input logic [7:0] y1, // 좌상단 (BRAM 기준)
//         input logic [8:0] x2, input logic [7:0] y2  // 우하단 (BRAM 기준)
//     );
//         begin
//             // 1. 상단 가로선 그리기 (y1 라인의 x1 ~ x2)
//             for (int x = x1; x <= x2; x++) begin
//                 write_ui_pixel(t_type, x[8:0], y1);
//             end
//             // 2. 하단 가로선 그리기 (y2 라인의 x1 ~ x2)
//             for (int x = x1; x <= x2; x++) begin
//                 write_ui_pixel(t_type, x[8:0], y2);
//             end
//             // 3. 좌측 세로선 그리기 (x1 라인의 y1 ~ y2)
//             for (int y = y1; y <= y2; y++) begin
//                 write_ui_pixel(t_type, x1, y[7:0]);
//             end
//             // 4. 우측 세로선 그리기 (x2 라인의 y1 ~ y2)
//             for (int y = y1; y <= y2; y++) begin
//                 write_ui_pixel(t_type, x2, y[7:0]);
//             end
//         end
//     endtask

//     // =========================================================
//     // Task: 디스플레이 판독 주사 (Read Protocol)
//     // =========================================================
//     task automatic scan_display_window(
//         input logic [9:0] start_x, input logic [9:0] end_x,
//         input logic [9:0] start_y, input logic [9:0] end_y);
//         begin
//             for (int y = start_y; y <= end_y; y++) begin
//                 for (int x = start_x; x <= end_x; x++) begin
//                     @(posedge read_clk);
//                     de <= 1'b1;
//                     x_pixel <= x;
//                     y_pixel <= y;
//                     i_camera_rgb <= 12'hAAA; // 배경으로 쓸 고유의 카메라 색상 고정 인가
//                 end
//                 // 라인 동기화 공백 모사
//                 @(posedge read_clk);
//                 de <= 1'b0;
//                 x_pixel <= '0;
//                 y_pixel <= '0;
//                 i_camera_rgb <= 12'h000;
//                 #(READ_CLK_PERIOD * 4);
//             end
//         end
//     endtask

//     // =========================================================
//     // 메인 테스트 시나리오 제어 레이어
//     // =========================================================
//     initial begin
//         // 물리 로그 파일 생성 및 오픈
//         log_file = $fopen("tb_ui_framebuffer.log", "w");
//         if (log_file == 0) begin
//             $display(
//                 "[FATAL ERROR] tb_ui_framebuffer.log 파일을 열 수 없습니다.");
//             $finish;
//         end

//         $fdisplay(log_file,
//                   "=========================================================");
//         $fdisplay(log_file,
//                   "  UI GRAPHICS OVERLAY PIPELINE INTEGRATION TEST LOG");
//         $fdisplay(
//             log_file,
//             "=========================================================\n");

//         // 초기 조건 인가
//         reset = 1'b1;
//         valid = 1'b0;
//         target_type = 1'b0;
//         box_x = '0;
//         box_y = '0;
//         x_pixel = '0;
//         y_pixel = '0;
//         de = 1'b0;
//         i_camera_rgb = 12'h000;

//         // 정답지 메모리 공간의 디폴트 값을 투명 배경(12'hAAA)으로 빌드
//         for (int i = 0; i < WIDTH; i++) begin
//             for (int j = 0; j < HEIGHT; j++) begin
//                 expected_rgb[i][j] = 12'hAAA;
//             end
//         end

//         #(WRITE_CLK_PERIOD * 10);
//         reset = 1'b0;
//         #(WRITE_CLK_PERIOD * 5);

//         $display(
//             "[TB STATUS] 래스터 주사 방식 순차적 데이터 입력 트리거");
//         $fdisplay(
//             log_file,
//             "[TB STATUS] 래스터 주사 방식 순차적 데이터 입력 트리거");

//         // [SCENARIO 1: 쓰기] 네모 박스 테두리의 모든 좌표를 순차적으로 주입
//         // 적군 박스 그리기: 좌상단(43, 73) ~ 우하단(47, 77) -> 중심 (45, 75)
//         write_ui_box(.t_type(1'b0), .x1(9'd43), .y1(8'd73), .x2(9'd47), .y2(8'd77));

//         // 아군 박스 그리기: 좌상단(178, 138) ~ 우하단(182, 142) -> 중심 (180, 140)
//         write_ui_box(.t_type(1'b1), .x1(9'd178), .y1(8'd138), .x2(9'd182), .y2(8'd142));

//         $display(
//             "[TB STATUS] UI 타겟 픽셀 주입 완료. 1차 디스플레이 합성 출력 판독 시작");
//         $fdisplay(
//             log_file,
//             "[TB STATUS] UI 타겟 픽셀 주입 완료. 1차 디스플레이 합성 출력 판독 시작");
//         #(WRITE_CLK_PERIOD * 20);

//         // [SCENARIO 2: 1차 읽기] 타겟 포인트가 분포된 화면 영역을 VGA 스케일(2배)로 주사 판독
//         // Point 1 (45, 75) -> VGA(90, 150) 주변 스캔 (수평 80~100, 수직 140~160 범위 확장)
//         scan_display_window(.start_x(10'd80), .end_x(10'd100), .start_y(10'd140),
//                             .end_y(10'd160));

//         // Point 2 (180, 140) -> VGA(360, 280) 주변 스캔 (수평 350~370, 수직 270~290 범위 확장)
//         scan_display_window(.start_x(10'd350), .end_x(10'd370),
//                             .start_y(10'd270), .end_y(10'd290));

//         #(READ_CLK_PERIOD * 50);

//         $display(
//             "[TB STATUS] 2차 재스캔 수행을 통한 자동 소거(투명도 복원) 메커니즘 검증");
//         $fdisplay(
//             log_file,
//             "[TB STATUS] 2차 재스캔 수행을 통한 자동 소거(투명도 복원) 메커니즘 검증");

//         // [SCENARIO 3: 2차 읽기] 동일 포인트 영역을 한 번 더 스캔하여 카메라 원본 배경(12'hAAA)으로 돌아왔는지 점검
//         scan_display_window(.start_x(10'd80), .end_x(10'd100), .start_y(10'd140),
//                             .end_y(10'd160));

//         #(READ_CLK_PERIOD * 100);
//         $display("=========================================================");
//         $display(
//             "[SUCCESS] 모든 UI 파이프라인 연동 시뮬레이션 종료, 로그를 확인하십시오.");
//         $display("=========================================================");
//         $fdisplay(
//             log_file,
//             "\n=========================================================");
//         $fdisplay(log_file, "  SUCCESS - PIPELINE PASS RATE 100%%");
//         $fdisplay(log_file,
//                   "=========================================================");

//         $fclose(log_file);
//         $finish;
//     end

//     // 최종 12비트 출력 데이터 검증
//     always_ff @(posedge read_clk) begin
//         if (de_d2) begin
//             expected_rgb_val = expected_rgb[x_px_d2/2][y_px_d2/2];

//             if (w_bitmap_pixel !== 2'bxx) begin // 메모리 미초기화 영역 검증 제외
//                 if (o_screen_rgb !== expected_rgb_val) begin
//                     $error(
//                         "[FAIL] UI 합성 결함 발생! VGA 좌표(%0d, %0d) -> 예상 12비트: %3h, 실제 출력: %3h",
//                         x_px_d2, y_px_d2, expected_rgb_val, o_screen_rgb);
//                     $fdisplay(
//                         log_file,
//                         "[FAIL @ %0t ns] VGA 좌표(%0d, %0d) -> 예상 12비트: %3h, 실제 출력: %3h",
//                         $time, x_px_d2, y_px_d2, expected_rgb_val,
//                         o_screen_rgb);
//                 end else if (o_screen_rgb != 12'hAAA) begin
//                     // 원본 카메라 배경(12'hAAA)이 아닌 UI 레이어가 올라간 유효 픽셀만 타겟 로그 보존
//                     $fdisplay(
//                         log_file,
//                         "[PASS] 시간: %10t ns | VGA좌표 (%3d, %3d) -> UI 최종 12-bit 합성 RGB: %3h (%s 표식)",
//                         $time, x_px_d2, y_px_d2, o_screen_rgb,
//                         (o_screen_rgb == 12'hF00) ? "ENEMY RED" : "ALLY GREEN");
//                 end
//             end
//         end
//     end

// endmodule

`timescale 1ns / 1ps

module tb_ui_framebuffer;

    // 시스템 및 해상도 파라미터 정의
    localparam int WIDTH = 320;
    localparam int HEIGHT = 240;
    localparam int ADDR_W = $clog2(WIDTH * HEIGHT);

    // 하드웨어 타이밍 정합성을 위한 100MHz 동기 클록 주기 (10ns)
    localparam real WRITE_CLK_PERIOD = 10.00;
    localparam real READ_CLK_PERIOD  = 41.00; // 실시간 VGA 픽셀 동기 오프셋

    // 공통 및 쓰기(카메라) 도메인 신호 선언
    logic write_clk, read_clk, reset;
    logic ready, done;
    logic valid, target_type;
    logic [8:0] box_x;
    logic [7:0] box_y;

    // 읽기(디스플레이) 도메인 신호 선언
    logic [9:0] x_pixel, y_pixel;
    logic de;
    logic [11:0] i_camera_rgb; // 원본 카메라 입력 (배경 투명도 검증용)

    logic [11:0] i_camera_rgb_d1, i_camera_rgb_d2;
    logic [9:0] x_px_d1, x_px_d2;
    logic [9:0] y_px_d1, y_px_d2;
    logic de_d1, de_d2;

    logic [11:0] expected_rgb_val;

    // BRAM 판독 지연과 SCREEN_MUX 조합 회로 타이밍을 추적하기 위해 2사이클 파이프라인 매칭 지연 적용
    always_ff @(posedge read_clk) begin
        i_camera_rgb_d1 <= i_camera_rgb;
        i_camera_rgb_d2 <= i_camera_rgb_d1;
        de_d1           <= de;
        de_d2           <= de_d1;
        x_px_d1         <= x_pixel;
        x_px_d2         <= x_px_d1;
        y_px_d1         <= y_pixel;
        y_px_d2         <= y_px_d1;
    end

    // 내부 모듈 간 상호 연결 와이어 선언
    logic [1:0] w_bitmap_pixel;

    // 최종 검증 대상 출력 신호 (12비트 합성 RGB)
    logic [11:0] o_screen_rgb;

    // 로그 파일 식별 변수
    int log_file;

    // 시나리오 통계 검증용 통합 카운터 선언
    int exp_red_count, act_red_count;
    int exp_green_count, act_green_count;
    int exp_bg_count, act_bg_count;
    int total_fail_count = 0; // 전체 프레임 결함 누적 개수
    
    // [추가] BRAM 미초기화 영역을 하드웨어적으로 청소하기 위한 초기화 제어 신호
    logic init_phase = 1'b0;

    // =========================================================
    // 1. 모듈 통합 인스턴스화 (DUT 환경 구축)
    // =========================================================

    // UI 프레임버퍼 (하부에 내부적으로 bitmap_bram을 포함하여 구동됨)
    ui_framebuffer #(
        .WIDTH (WIDTH),
        .HEIGHT(HEIGHT),
        .ADDR_W(ADDR_W)
    ) u_framebuffer (
        .write_clk   (write_clk),
        .read_clk    (read_clk),
        .reset       (reset),
        .ready       (ready),
        .done        (done),
        .valid       (valid),
        .target_type (target_type),
        .box_x       (box_x),
        .box_y       (box_y),
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .de          (de),
        .bitmap_pixel(w_bitmap_pixel)  // 포트 B 판독 인덱스 출력
    );

    // 최종 단 합성 멀티플렉서 (SCREEN_MUX)
    SCREEN_MUX u_screen_mux (
        .ui_enable(1'b1),  // UI 표시 기능 마스터 활성화
        .i_camera_rgb(i_camera_rgb_d2),  // 원본 배경 입력
        .i_bitmap_pixel (w_bitmap_pixel),  // 버퍼가 뿜어내는 2비트 인덱스 수신
        .o_screen_rgb(o_screen_rgb)  // 최종 12비트 출력 관측 대상
    );

    // 클록 생성 엔진
    initial begin
        write_clk = 0;
        forever #(WRITE_CLK_PERIOD / 2.0) write_clk = ~write_clk;
    end
    initial begin
        read_clk = 0;
        forever #(READ_CLK_PERIOD / 2.0) read_clk = ~read_clk;
    end

    // =========================================================
    // 스코어보드 (Scoreboard) - 12비트 최종 RGB 기대치 역추적용 메모리
    // =========================================================
    logic [11:0] expected_rgb[0:WIDTH-1][0:HEIGHT-1];

    // 읽기 도메인 주사 시 자동 소거 타이밍(x[0]&&y[0])에 맞춰 정답지도 투명(UI_NONE)으로 동기화 초기화
    always_ff @(posedge read_clk) begin
        if (de_d2 && x_px_d2[0] && y_px_d2[0]) begin
            expected_rgb[x_px_d2/2][y_px_d2/2] <= 12'hAAA; // 기본 카메라 데이터(배경) 복원 기대치
        end
    end

    // =========================================================
    // Task: 유효 픽셀 데이터 주입 (Write Protocol)
    // =========================================================
    task automatic write_ui_pixel(input logic t_type, input logic [8:0] x,
                                  input logic [7:0] y);
        begin
            while (!ready)
            @(posedge write_clk);  // 버퍼 FSM 준비 상태 확인 대기

            valid              <= 1'b1;
            target_type        <= t_type;
            box_x              <= x;
            box_y              <= y;

            // 최종 12비트 RGB 정답 예측 테이블 설정 (적군: RED=12'hF00 / 아군: GREEN=12'h0F0)
            expected_rgb[x][y] <= t_type ? 12'h0F0 : 12'hF00;

            @(posedge write_clk);
            valid       <= 1'b0;
            target_type <= 1'b0;
            box_x       <= '0;
            box_y       <= '0;

            while (!done)
            @(posedge write_clk);  // 내부 BRAM 적재 완료 확인 대기
            @(posedge write_clk);
        end
    endtask

    // =========================================================
    // Task: 네모 박스 테두리 좌표 순차 주입 (Box Outline Protocol)
    // =========================================================
    task automatic write_ui_box(
        input logic t_type,
        input logic [8:0] x1, input logic [7:0] y1, // 좌상단 (BRAM 기준)
        input logic [8:0] x2, input logic [7:0] y2  // 우하단 (BRAM 기준)
    );
        begin
            // 1. 상단 가로선 그리기 (y1 라인의 x1 ~ x2)
            for (int x = x1; x <= x2; x++) begin
                write_ui_pixel(t_type, x[8:0], y1);
            end
            // 2. 하단 가로선 그리기 (y2 라인의 x1 ~ x2)
            for (int x = x1; x <= x2; x++) begin
                write_ui_pixel(t_type, x[8:0], y2);
            end
            // 3. 좌측 세로선 그리기 (x1 라인의 y1 ~ y2)
            for (int y = y1; y <= y2; y++) begin
                write_ui_pixel(t_type, x1, y[7:0]);
            end
            // 4. 우측 세로선 그리기 (x2 라인의 y1 ~ y2)
            for (int y = y1; y <= y2; y++) begin
                write_ui_pixel(t_type, x2, y[7:0]);
            end
        end
    endtask

    // =========================================================
    // Task: 디스플레이 판독 주사 (Read Protocol)
    // =========================================================
    task automatic scan_display_window(
        input logic [9:0] start_x, input logic [9:0] end_x,
        input logic [9:0] start_y, input logic [9:0] end_y);
        begin
            for (int y = start_y; y <= end_y; y++) begin
                for (int x = start_x; x <= end_x; x++) begin
                    @(posedge read_clk);
                    de <= 1'b1;
                    x_pixel <= x;
                    y_pixel <= y;
                    i_camera_rgb <= 12'hAAA; // 배경으로 쓸 고유의 카메라 색상 고정 인가
                end
                // 라인 동기화 공백 모사
                @(posedge read_clk);
                de <= 1'b0;
                x_pixel <= '0;
                y_pixel <= '0;
                i_camera_rgb <= 12'h000;
                #(READ_CLK_PERIOD * 4);
            end
        end
    endtask

    // =========================================================
    // 통계 유틸리티 태스크군 (Helper Tasks)
    // =========================================================
    task automatic reset_counters();
        begin
            exp_red_count   = 0;
            act_red_count   = 0;
            exp_green_count = 0;
            act_green_count = 0;
            exp_bg_count    = 0;
            act_bg_count    = 0;
        end
    endtask

    task automatic print_scenario_report(input string phase_name);
        begin
            $fdisplay(log_file, "\n=========================================================");
            $fdisplay(log_file, " [SUMMARY REPORT] %s", phase_name);
            $fdisplay(log_file, "=========================================================");
            $display("\n=========================================================");
            $display(" [SUMMARY REPORT] %s", phase_name);
            $display("=========================================================");

            // 1. RED 검증 요약
            if (exp_red_count == act_red_count) begin
                $fdisplay(log_file, "[PASS!] Expected pixel count: %0d, Expected color: RED / Actual pixel count: %0d, Actual color: RED", exp_red_count, act_red_count);
                $display("[PASS!] Expected pixel count: %0d, Expected color: RED / Actual pixel count: %0d, Actual color: RED", exp_red_count, act_red_count);
            end else begin
                $fdisplay(log_file, "[FAIL!!] Expected pixel count: %0d, Expected color: RED / Actual pixel count: %0d, Actual color: RED", exp_red_count, act_red_count);
                $display("[FAIL!!] Expected pixel count: %0d, Expected color: RED / Actual pixel count: %0d, Actual color: RED", exp_red_count, act_red_count);
            end

            // 2. GREEN 검증 요약
            if (exp_green_count == act_green_count) begin
                $fdisplay(log_file, "[PASS!] Expected pixel count: %0d, Expected color: GREEN / Actual pixel count: %0d, Actual color: GREEN", exp_green_count, act_green_count);
                $display("[PASS!] Expected pixel count: %0d, Expected color: GREEN / Actual pixel count: %0d, Actual color: GREEN", exp_green_count, act_green_count);
            end else begin
                $fdisplay(log_file, "[FAIL!!] Expected pixel count: %0d, Expected color: GREEN / Actual pixel count: %0d, Actual color: GREEN", exp_green_count, act_green_count);
                $display("[FAIL!!] Expected pixel count: %0d, Expected color: GREEN / Actual pixel count: %0d, Actual color: GREEN", exp_green_count, act_green_count);
            end

            // 3. BACKGROUND 검증 요약
            if (exp_bg_count == act_bg_count) begin
                $fdisplay(log_file, "[PASS!] Expected pixel count: %0d, Expected color: BG(AAA) / Actual pixel count: %0d, Actual color: BG(AAA)", exp_bg_count, act_bg_count);
                $display("[PASS!] Expected pixel count: %0d, Expected color: BG(AAA) / Actual pixel count: %0d, Actual color: BG(AAA)", exp_bg_count, act_bg_count);
            end else begin
                $fdisplay(log_file, "[FAIL!!] Expected pixel count: %0d, Expected color: BG(AAA) / Actual pixel count: %0d, Actual color: BG(AAA)", exp_bg_count, act_bg_count);
                $display("[FAIL!!] Expected pixel count: %0d, Expected color: BG(AAA) / Actual pixel count: %0d, Actual color: BG(AAA)", exp_bg_count, act_bg_count);
            end

            $fdisplay(log_file, "=========================================================\n");
            $display("=========================================================\n");
        end
    endtask

    // =========================================================
    // 메인 테스트 시나리오 제어 레이어
    // =========================================================
    initial begin
        // 물리 로그 파일 생성 및 오픈
        log_file = $fopen("tb_ui_framebuffer.log", "w");
        if (log_file == 0) begin
            $display("[FATAL ERROR] tb_ui_framebuffer.log 파일을 열 수 없습니다.");
            $finish;
        end

        $fdisplay(log_file, "=========================================================");
        $fdisplay(log_file, "  OSD GRAPHICS OVERLAY PIPELINE INTEGRATION TEST LOG");
        $fdisplay(log_file, "=========================================================");

        // 초기 조건 인가
        reset = 1'b1;
        valid = 1'b0;
        target_type = 1'b0;
        box_x = '0;
        box_y = '0;
        x_pixel = '0;
        y_pixel = '0;
        de = 1'b0;
        i_camera_rgb = 12'h000;

        // 정답지 메모리 공간의 디폴트 값을 투명 배경(12'hAAA)으로 빌드
        for (int i = 0; i < WIDTH; i++) begin
            for (int j = 0; j < HEIGHT; j++) begin
                expected_rgb[i][j] = 12'hAAA;
            end
        end

        #(WRITE_CLK_PERIOD * 10);
        reset = 1'b0;
        #(WRITE_CLK_PERIOD * 5);

        // =========================================================
        // [수정 추가] BRAM 온더플라이 포맷 (VGA Pre-Scan)
        // 시나리오 시작 전, 목표 윈도우 영역의 미초기화 'X' 상태를 2'b00으로 정리
        // =========================================================
        init_phase = 1'b1;
        $display("[TB STATUS] Pre-scanning target windows to format BRAM to 2'b00...");
        scan_display_window(.start_x(10'd80), .end_x(10'd101), .start_y(10'd140), .end_y(10'd161));
        scan_display_window(.start_x(10'd350), .end_x(10'd371), .start_y(10'd270), .end_y(10'd291));
        #(READ_CLK_PERIOD * 10);
        init_phase = 1'b0;

        $display("[TB STATUS] Triggering sequential data input via raster scan");
        $fdisplay(log_file, "[TB STATUS] Triggering sequential data input via raster scan");

        // [SCENARIO 1: 쓰기] 네모 박스 테두리의 모든 좌표를 순차적으로 주입
        // 적군 박스 그리기: 좌상단(43, 73) ~ 우하단(47, 77) -> 중심 (45, 75)
        write_ui_box(.t_type(1'b0), .x1(9'd43), .y1(8'd73), .x2(9'd47), .y2(8'd77));

        // 아군 박스 그리기: 좌상단(178, 138) ~ 우하단(182, 142) -> 중심 (180, 140)
        write_ui_box(.t_type(1'b1), .x1(9'd178), .y1(8'd138), .x2(9'd182), .y2(8'd142));

        $display("[TB STATUS] OSD target pixel injection complete. Starting 1st display readback");
        $fdisplay(log_file, "[TB STATUS] OSD target pixel injection complete. Starting 1st display readback");
        #(WRITE_CLK_PERIOD * 20);

        // [SCENARIO 2: 1차 읽기] 카운터 리셋 후 윈도우 판독 스캔 가동 (미초기화 없음 $\rightarrow$ 정확히 754개 BG 검출 기대)
        reset_counters();
        scan_display_window(.start_x(10'd80), .end_x(10'd100), .start_y(10'd140), .end_y(10'd160));
        scan_display_window(.start_x(10'd350), .end_x(10'd370), .start_y(10'd270), .end_y(10'd290));

        // 마지막 픽셀 분석 대기 후 리포트 출력
        #(READ_CLK_PERIOD * 5);
        print_scenario_report("1st Display Composite Read");

        // [SCENARIO 3: 2차 읽기] 자동 소거 및 투명도 복원 정합성 검증 (정확히 441개 BG 검출 기대)
        $display("[TB STATUS] Starting 2nd rescan for self-clearing verification");
        $fdisplay(log_file, "[TB STATUS] Starting 2nd rescan for self-clearing verification");
        
        reset_counters();
        scan_display_window(.start_x(10'd80), .end_x(10'd100), .start_y(10'd140), .end_y(10'd160));
        scan_display_window(.start_x(10'd350), .end_x(10'd370), .start_y(10'd270), .end_y(10'd290));

        #(READ_CLK_PERIOD * 5);
        print_scenario_report("2nd Rescan Self-Clearing");

        // 최종 합격율 계산 및 보존
        $display("=========================================================");
        $display("[SUCCESS] All simulation scenarios finished. Please check the log file.");
        $display("=========================================================");
        
        $fdisplay(log_file, "\n=========================================================");
        if (total_fail_count == 0) begin
            $fdisplay(log_file, "  SUCCESS - PIPELINE PASS RATE 100%%");
            $display("  SUCCESS - PIPELINE PASS RATE 100%%");
        end else begin
            $fdisplay(log_file, "  FAIL - MISMATCH PIXEL DETECTED: %0d", total_fail_count);
            $display("  FAIL - MISMATCH PIXEL DETECTED: %0d", total_fail_count);
        end
        $fdisplay(log_file, "=========================================================");

        $fclose(log_file);
        $finish;
    end

    // =========================================================
    // 실시간 비동기 모니터링 & 자가 검증 (Dual Action: Individual & Aggregated)
    // =========================================================
    always_ff @(posedge read_clk) begin
        if (de_d2 && !init_phase) begin // [수정] 포맷(Pre-Scan) 시기에는 검증 카운트를 보류함
            expected_rgb_val = expected_rgb[x_px_d2/2][y_px_d2/2];

            if (w_bitmap_pixel !== 2'bxx) begin // 메모리 미초기화 영역 검증 제외
                
                // 1. 예상 정답 데이터 분류 누적 (통계용)
                if (expected_rgb_val == 12'hF00)      exp_red_count++;
                else if (expected_rgb_val == 12'h0F0) exp_green_count++;
                else                                  exp_bg_count++;

                // 2. 실제 출력 데이터 분류 누적 (통계용)
                if (o_screen_rgb == 12'hF00)      act_red_count++;
                else if (o_screen_rgb == 12'h0F0) act_green_count++;
                else                              act_bg_count++;

                // 3. 개별 픽셀 실시간 판정 및 로그 출력
                if (o_screen_rgb !== expected_rgb_val) begin
                    total_fail_count++;
                    $error("[FAIL] OSD synthesis mismatch! VGA Coord(%0d, %0d) -> Expected 12-bit: %3h, Actual: %3h",
                           x_px_d2, y_px_d2, expected_rgb_val, o_screen_rgb);
                    $fdisplay(log_file, "[FAIL @ %0t ns] VGA Coord(%0d, %0d) -> Expected 12-bit: %3h, Actual: %3h",
                              $time, x_px_d2, y_px_d2, expected_rgb_val, o_screen_rgb);
                end else if (o_screen_rgb != 12'hAAA) begin
                    $fdisplay(log_file, "[PASS] Time: %10t ns | VGA Coord (%3d, %3d) -> Final 12-bit Composite RGB: %3h (%s Marker)",
                              $time, x_px_d2, y_px_d2, o_screen_rgb,
                              (o_screen_rgb == 12'hF00) ? "RED(ENEMY)" : "GREEN(ALLY)");
                end
            end
        end
    end

endmodule