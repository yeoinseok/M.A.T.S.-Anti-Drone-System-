// `timescale 1ns / 1ps

// module tb_Frame_Set;

//     localparam logic [11:0] RED      = 12'hF00;
//     localparam logic [11:0] GREEN    = 12'h0F0;
//     localparam logic [11:0] WHITE    = 12'hFFF;
//     localparam logic [11:0] BASE_RGB = 12'h48C;

//     logic clk;
//     logic reset;

//     logic        h_sync_i;
//     logic        v_sync_i;
//     logic [9:0]  x_pixel;
//     logic [9:0]  y_pixel;
//     logic        de;
//     logic [11:0] screen_rgb;
//     logic        friend_detect;
//     logic        enemy_detect;

//     logic       h_sync;
//     logic       v_sync;
//     logic [3:0] port_red;
//     logic [3:0] port_green;
//     logic [3:0] port_blue;
//     logic [11:0] vga_rgb;

//     integer check_count;
//     integer error_count;

//     assign vga_rgb = {
//         port_red,
//         port_green,
//         port_blue
//     };

//     Frame_Set DUT (
//         .clk_100M      (clk),
//         .reset         (reset),
//         .h_sync_i      (h_sync_i),
//         .v_sync_i      (v_sync_i),
//         .x_pixel       (x_pixel),
//         .y_pixel       (y_pixel),
//         .de            (de),
//         .screen_rgb    (screen_rgb),
//         .friend_detect (friend_detect),
//         .enemy_detect  (enemy_detect),
//         .h_sync        (h_sync),
//         .v_sync        (v_sync),
//         .port_red      (port_red),
//         .port_green    (port_green),
//         .port_blue     (port_blue)
//     );

//     initial clk = 1'b0;
//     always #5 clk = ~clk;

//     task automatic check_pixel(
//         input logic [9:0]  test_x,
//         input logic [9:0]  test_y,
//         input logic [11:0] expected_rgb,
//         input string       check_name
//     );
//         begin
//             x_pixel = test_x;
//             y_pixel = test_y;
//             de      = 1'b1;

//             #50;

//             check_count = check_count + 1;

//             if (vga_rgb !== expected_rgb) begin
//                 error_count = error_count + 1;

//                 $display(
//                     "FAIL: %s X=%0d Y=%0d EXPECTED=%03h ACTUAL=%03h",
//                     check_name,
//                     test_x,
//                     test_y,
//                     expected_rgb,
//                     vga_rgb
//                 );
//             end else begin
//                 $display(
//                     "PASS: %s X=%0d Y=%0d RGB=%03h",
//                     check_name,
//                     test_x,
//                     test_y,
//                     vga_rgb
//                 );
//             end
//         end
//     endtask

//     initial begin
//         reset         = 1'b1;
//         h_sync_i      = 1'b0;
//         v_sync_i      = 1'b0;
//         x_pixel       = 10'd0;
//         y_pixel       = 10'd0;
//         de            = 1'b0;
//         screen_rgb    = BASE_RGB;
//         friend_detect = 1'b0;
//         enemy_detect  = 1'b0;
//         check_count   = 0;
//         error_count   = 0;

//         // Reset 2클럭
//         repeat (2) @(posedge clk);
//         reset = 1'b0;

//         #100;

//         // 01: 적군
//         $display("----- CASE 01 ENEMY -----");

//         friend_detect = 1'b0;
//         enemy_detect  = 1'b1;

//         check_pixel(10'd5,   10'd100, RED,      "LEFT BORDER");
//         check_pixel(10'd635, 10'd100, RED,      "RIGHT BORDER");
//         check_pixel(10'd100, 10'd5,   RED,      "TOP BORDER");
//         check_pixel(10'd100, 10'd475, RED,      "BOTTOM BORDER");
//         check_pixel(10'd226, 10'd452, WHITE,    "ENEMY TEXT");
//         check_pixel(10'd100, 10'd100, BASE_RGB, "CAMERA AREA");

//         // 케이스 간격
//         friend_detect = 1'b0;
//         enemy_detect  = 1'b0;
//         de            = 1'b0;

//         #100;

//         // 10: 아군
//         $display("----- CASE 10 FRIEND -----");

//         friend_detect = 1'b1;
//         enemy_detect  = 1'b0;

//         check_pixel(10'd5,   10'd100, GREEN,    "LEFT BORDER");
//         check_pixel(10'd635, 10'd100, GREEN,    "RIGHT BORDER");
//         check_pixel(10'd100, 10'd5,   GREEN,    "TOP BORDER");
//         check_pixel(10'd100, 10'd475, GREEN,    "BOTTOM BORDER");
//         check_pixel(10'd270, 10'd452, WHITE,    "SAFE ZONE TEXT");
//         check_pixel(10'd100, 10'd100, BASE_RGB, "CAMERA AREA");

//         // 케이스 간격
//         friend_detect = 1'b0;
//         enemy_detect  = 1'b0;
//         de            = 1'b0;

//         #100;

//         // 11: 동시 검출, 적군 우선
//         $display("----- CASE 11 BOTH -----");

//         friend_detect = 1'b1;
//         enemy_detect  = 1'b1;

//         check_pixel(10'd5,   10'd100, RED,      "LEFT BORDER");
//         check_pixel(10'd635, 10'd100, RED,      "RIGHT BORDER");
//         check_pixel(10'd100, 10'd5,   RED,      "TOP BORDER");
//         check_pixel(10'd100, 10'd475, RED,      "BOTTOM BORDER");
//         check_pixel(10'd226, 10'd452, WHITE,    "ENEMY TEXT");
//         check_pixel(10'd100, 10'd100, BASE_RGB, "CAMERA AREA");

//         $display("--------------------------------");
//         $display("TOTAL CHECKED = %0d", check_count);
//         $display("TOTAL ERRORS  = %0d", error_count);

//         if (error_count == 0)
//             $display("FRAME_SET SPOT TEST PASS");
//         else
//             $display("FRAME_SET SPOT TEST FAIL");

//         $display("--------------------------------");

//         #10;
//         $finish;
//     end

// endmodule

















































// `timescale 1ns / 1ps

// module tb_Frame_Set;

//     localparam logic [11:0] RED      = 12'hF00;
//     localparam logic [11:0] GREEN    = 12'h0F0;
//     localparam logic [11:0] WHITE    = 12'hFFF;
//     localparam logic [11:0] BLACK    = 12'h000;
//     localparam logic [11:0] BASE_RGB = 12'h000;

//     localparam integer H_ACTIVE = 640;
//     localparam integer V_ACTIVE = 480;

//     logic clk;
//     logic reset;

//     logic        h_sync_i;
//     logic        v_sync_i;
//     logic [9:0]  x_pixel;
//     logic [9:0]  y_pixel;
//     logic        de;
//     logic [11:0] screen_rgb;
//     logic        friend_detect;
//     logic        enemy_detect;

//     logic        h_sync;
//     logic        v_sync;
//     logic [3:0]  port_red;
//     logic [3:0]  port_green;
//     logic [3:0]  port_blue;
//     logic [11:0] vga_rgb;

//     logic expected_text_on;

//     integer check_count;
//     integer error_count;
//     integer case_check_count;
//     integer case_error_count;

//     assign vga_rgb = {
//         port_red,
//         port_green,
//         port_blue
//     };

//     Frame_Set DUT (
//         .clk_100M      (clk),
//         .reset         (reset),
//         .h_sync_i      (h_sync_i),
//         .v_sync_i      (v_sync_i),
//         .x_pixel       (x_pixel),
//         .y_pixel       (y_pixel),
//         .de            (de),
//         .screen_rgb    (screen_rgb),
//         .friend_detect (friend_detect),
//         .enemy_detect  (enemy_detect),
//         .h_sync        (h_sync),
//         .v_sync        (v_sync),
//         .port_red      (port_red),
//         .port_green    (port_green),
//         .port_blue     (port_blue)
//     );

  
//     text_status_pixel EXPECTED_TEXT (
//         .x_pixel       (x_pixel),
//         .y_pixel       (y_pixel),
//         .upscale_mode  (1'b1),
//         .friend_detect (friend_detect),
//         .enemy_detect  (enemy_detect),
//         .pixel_on      (expected_text_on)
//     );

    
//     initial begin
//         clk = 1'b0;
//     end

//     always #5 clk = ~clk;

   
//     function automatic logic expected_in_frame(
//         input integer test_x,
//         input integer test_y
//     );
//         logic in_left_border;
//         logic in_right_border;
//         logic in_top_border;
//         logic in_bottom_border;
//         logic in_status_bar;

//         begin
//             in_left_border =
//                 (test_x >= 0) &&
//                 (test_x < 10) &&
//                 (test_y >= 0) &&
//                 (test_y < 480);

//             in_right_border =
//                 (test_x >= 630) &&
//                 (test_x < 640) &&
//                 (test_y >= 0) &&
//                 (test_y < 480);

//             in_top_border =
//                 (test_x >= 0) &&
//                 (test_x < 640) &&
//                 (test_y >= 0) &&
//                 (test_y < 10);

//             in_bottom_border =
//                 (test_x >= 0) &&
//                 (test_x < 640) &&
//                 (test_y >= 470) &&
//                 (test_y < 480);

//             in_status_bar =
//                 (test_x >= 0) &&
//                 (test_x < 640) &&
//                 (test_y >= 440) &&
//                 (test_y < 480);

//             expected_in_frame =
//                 in_left_border   ||
//                 in_right_border  ||
//                 in_top_border    ||
//                 in_bottom_border ||
//                 in_status_bar;
//         end
//     endfunction

//     function automatic logic [11:0] get_expected_rgb(
//         input integer test_x,
//         input integer test_y,
//         input logic   test_de,
//         input logic   test_friend,
//         input logic   test_enemy,
//         input logic   test_text_on
//     );
//         logic in_frame;

//         begin
//             in_frame = expected_in_frame(test_x, test_y);

//             if (!test_de) begin
//                 get_expected_rgb = BLACK;
//             end
//             else if (
//                 (test_friend || test_enemy) &&
//                 test_text_on
//             ) begin
//                 get_expected_rgb = WHITE;
//             end
//             else if (
//                 test_enemy &&
//                 in_frame
//             ) begin
//                 get_expected_rgb = RED;
//             end
//             else if (
//                 test_friend &&
//                 !test_enemy &&
//                 in_frame
//             ) begin
//                 get_expected_rgb = GREEN;
//             end
//             else begin
//                 get_expected_rgb = BASE_RGB;
//             end
//         end
//     endfunction

    
//     task automatic check_full_frame(
//         input logic  test_friend,
//         input logic  test_enemy,
//         input string case_name
//     );
//         integer x;
//         integer y;
//         logic [11:0] expected_rgb;

//         begin
//             $display("");
//             $display("----------------------------------------");
//             $display("START FULL FRAME: %s", case_name);
//             $display(
//                 "FRIEND=%0b ENEMY=%0b",
//                 test_friend,
//                 test_enemy
//             );
//             $display("----------------------------------------");

//             friend_detect   = test_friend;
//             enemy_detect    = test_enemy;
//             de              = 1'b1;
//             case_check_count = 0;
//             case_error_count = 0;

          
//             for (y = 0; y < V_ACTIVE; y = y + 1) begin
//                 for (x = 0; x < H_ACTIVE; x = x + 1) begin
//                     x_pixel = x;
//                     y_pixel = y;
//                     de      = 1'b1;

                   
//                     #50;

//                     expected_rgb = get_expected_rgb(
//                         x,
//                         y,
//                         de,
//                         test_friend,
//                         test_enemy,
//                         expected_text_on
//                     );

//                     check_count      = check_count + 1;
//                     case_check_count = case_check_count + 1;

//                     if (vga_rgb !== expected_rgb) begin
//                         error_count      = error_count + 1;
//                         case_error_count = case_error_count + 1;

                        
//                         if (case_error_count <= 20) begin
//                             $display(
//                                 "FAIL: %s X=%0d Y=%0d EXPECTED=%03h ACTUAL=%03h TEXT=%0b",
//                                 case_name,
//                                 x,
//                                 y,
//                                 expected_rgb,
//                                 vga_rgb,
//                                 expected_text_on
//                             );
//                         end
//                     end
//                 end

             
//                 if ((y % 40) == 0) begin
//                     $display(
//                         "%s PROGRESS: Y=%0d / 479, ERRORS=%0d",
//                         case_name,
//                         y,
//                         case_error_count
//                     );
//                 end
//             end

//             $display("----------------------------------------");
//             $display("END FULL FRAME: %s", case_name);
//             $display(
//                 "CASE CHECKED = %0d",
//                 case_check_count
//             );
//             $display(
//                 "CASE ERRORS  = %0d",
//                 case_error_count
//             );

//             if (case_error_count == 0) begin
//                 $display("%s PASS", case_name);
//             end
//             else begin
//                 $display("%s FAIL", case_name);

//                 if (case_error_count > 20) begin
//                     $display(
//                         "Only first 20 errors were displayed."
//                     );
//                 end
//             end

//             $display("----------------------------------------");
//             $display("");
//         end
//     endtask

   
//     task automatic check_de_disabled;
//         logic [11:0] expected_rgb;

//         begin
//             $display("----- CHECK DE=0 -----");

//             friend_detect = 1'b1;
//             enemy_detect  = 1'b1;
//             x_pixel       = 10'd226;
//             y_pixel       = 10'd452;
//             de            = 1'b0;

//             #50;

//             expected_rgb = BLACK;
//             check_count  = check_count + 1;

//             if (vga_rgb !== expected_rgb) begin
//                 error_count = error_count + 1;

//                 $display(
//                     "FAIL: DE=0 EXPECTED=%03h ACTUAL=%03h",
//                     expected_rgb,
//                     vga_rgb
//                 );
//             end
//             else begin
//                 $display(
//                     "PASS: DE=0 RGB=%03h",
//                     vga_rgb
//                 );
//             end
//         end
//     endtask

    
//     task automatic check_sync_passthrough;
//         begin
//             $display("----- CHECK SYNC PASSTHROUGH -----");

//             h_sync_i = 1'b0;
//             v_sync_i = 1'b0;
//             #10;

//             check_count = check_count + 2;

//             if (h_sync !== 1'b0) begin
//                 error_count = error_count + 1;
//                 $display(
//                     "FAIL: H_SYNC INPUT=0 OUTPUT=%b",
//                     h_sync
//                 );
//             end

//             if (v_sync !== 1'b0) begin
//                 error_count = error_count + 1;
//                 $display(
//                     "FAIL: V_SYNC INPUT=0 OUTPUT=%b",
//                     v_sync
//                 );
//             end

//             h_sync_i = 1'b1;
//             v_sync_i = 1'b1;
//             #10;

//             check_count = check_count + 2;

//             if (h_sync !== 1'b1) begin
//                 error_count = error_count + 1;
//                 $display(
//                     "FAIL: H_SYNC INPUT=1 OUTPUT=%b",
//                     h_sync
//                 );
//             end

//             if (v_sync !== 1'b1) begin
//                 error_count = error_count + 1;
//                 $display(
//                     "FAIL: V_SYNC INPUT=1 OUTPUT=%b",
//                     v_sync
//                 );
//             end

//             h_sync_i = 1'b0;
//             v_sync_i = 1'b0;

//             $display("SYNC CHECK COMPLETE");
//         end
//     endtask

//     initial begin
       
//         reset          = 1'b1;
//         h_sync_i       = 1'b0;
//         v_sync_i       = 1'b0;
//         x_pixel        = 10'd0;
//         y_pixel        = 10'd0;
//         de             = 1'b0;
//         screen_rgb     = BASE_RGB;
//         friend_detect  = 1'b0;
//         enemy_detect   = 1'b0;
//         check_count    = 0;
//         error_count    = 0;
//         case_check_count = 0;
//         case_error_count = 0;

        
//         repeat (2) @(posedge clk);
//         reset = 1'b0;

//         #100;

        
//         check_full_frame(
//             1'b0,
//             1'b1,
//             "CASE 01 ENEMY"
//         );

      
//         friend_detect = 1'b0;
//         enemy_detect  = 1'b0;
//         de            = 1'b0;

//         #100;

//         check_full_frame(
//             1'b1,
//             1'b0,
//             "CASE 10 FRIEND"
//         );

       
//         friend_detect = 1'b0;
//         enemy_detect  = 1'b0;
//         de            = 1'b0;

//         #100;

        
//         check_full_frame(
//             1'b1,
//             1'b1,
//             "CASE 11 BOTH - ENEMY PRIORITY"
//         );

       
//         check_de_disabled();
//         check_sync_passthrough();

//         $display("");
//         $display("========================================");
//         $display("TOTAL CHECKED = %0d", check_count);
//         $display("TOTAL ERRORS  = %0d", error_count);

//         if (error_count == 0) begin
//             $display("FRAME_SET FULL FRAME TEST PASS");
//         end
//         else begin
//             $display("FRAME_SET FULL FRAME TEST FAIL");
//         end

//         $display("========================================");

//         #10;
//         $finish;
//     end

// endmodule