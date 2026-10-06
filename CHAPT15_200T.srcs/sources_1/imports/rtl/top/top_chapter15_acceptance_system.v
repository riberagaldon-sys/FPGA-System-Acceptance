`timescale 1ns/1ps

// Chapter 15: simulation, acceptance, scoring and report system.
// The functional datapath is the timing-closed Chapter-14 integrated system;
// this chapter adds full protocol/game regression, automated implementation
// acceptance and report generation around the verified hardware datapath.
// Target: XC7A200T-FBG484-2, GX-BIDT, 1024x600 RGB888 panel.
module top_chapter15_acceptance_system #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer POR_BITS        = 21,
    parameter integer PS2_DEVICE_MODE = 0
)(
    input  wire sys_clk,

    input  wire [3:0] I_SWC,
    output wire [3:0] O_SWR,

    input  wire S1_KEYA,
    input  wire S1_KEYB,
    input  wire S1_KEYC,
    input  wire S1_KEYD,
    input  wire S1_KEYP,
    input  wire EC_A,
    input  wire EC_B,
    input  wire EC_KEY,
    inout  wire PS2_CLK,
    inout  wire PS2_DATA,
    output wire TOUCH_SCL,
    inout  wire TOUCH_SDA,
    inout  wire TOUCH_INT,
    output wire TOUCH_RST,
    output wire [7:0] LCD_R,
    output wire [7:0] LCD_G,
    output wire [7:0] LCD_B,
    output wire       LCD_CLK,
    output wire       LCD_HSYNC,
    output wire       LCD_VSYNC,
    output wire       LCD_DE,
    output wire       LCD_BL,
    output wire       LCD_nRST,
    output wire [4:0] led
);

    wire rst_n;
    por_reset #(.COUNTER_BITS(POR_BITS)) u_por (
        .clk(sys_clk), .rst_n(rst_n)
    );

    // 50 MHz -> 51.2 MHz.  This exact clock removed the periodic striped
    // corruption during the completed Chapter-7 hardware verification.
    wire lcd_pix_clk_mmcm;
    wire lcd_pix_clk;
    wire lcd_clk_fb_mmcm;
    wire lcd_clk_fb;
    wire lcd_clk_locked;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(20.000),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(16.000),
        .CLKOUT0_DIVIDE_F(15.625),
        .STARTUP_WAIT("FALSE")
    ) u_lcd_mmcm (
        .CLKIN1(sys_clk), .CLKFBIN(lcd_clk_fb),
        .RST(~rst_n), .PWRDWN(1'b0),
        .CLKOUT0(lcd_pix_clk_mmcm),
        .CLKFBOUT(lcd_clk_fb_mmcm),
        .LOCKED(lcd_clk_locked)
    );

    BUFG u_lcd_clk_fb_buf (.I(lcd_clk_fb_mmcm), .O(lcd_clk_fb));
    BUFG u_lcd_pix_clk_buf(.I(lcd_pix_clk_mmcm), .O(lcd_pix_clk));

    // The POR counter is clocked by sys_clk (50 MHz), while all LCD/game
    // logic is clocked by lcd_pix_clk (51.2 MHz).  Driving the LCD ODDR reset
    // directly from rst_n creates a reset-recovery path between those two
    // clocks with only 0.156 ns available.  The MMCM LOCKED output asserts
    // low whenever the MMCM is reset or loses lock; use it for asynchronous
    // reset assertion and release reset through a three-stage synchronizer in
    // the destination clock domain.
    (* ASYNC_REG = "TRUE" *) reg [2:0] lcd_reset_sync;

    always @(posedge lcd_pix_clk or negedge lcd_clk_locked) begin
        if (!lcd_clk_locked)
            lcd_reset_sync <= 3'b000;
        else
            lcd_reset_sync <= {lcd_reset_sync[1:0], 1'b1};
    end

    wire lcd_logic_rst_n = lcd_reset_sync[2];

    wire event_up, event_down, event_left, event_right;
    wire event_ok, event_back, event_pause;
    wire [2:0] ui_state, menu_sel;
    wire [10:0] pointer_x;
    wire [9:0] pointer_y;
    wire pointer_down, pointer_click;
    wire [7:0] keyboard_code;
    wire keyboard_extended;
    wire [4:0] ec_count;
    wire [15:0] touch_x_raw, touch_y_raw;
    wire ft_flag;
    wire [15:0] chip_version;
    wire [6:0] touch_state;
    wire touch_coord_valid;
    wire game_exit_request;
    wire game_exit_event;

    wire keypad_valid;
    wire [3:0] keypad_code;

    keypad4x4_scan #(
        .CLK_HZ(51_200_000),
        .ROW_SCAN_HZ(1000),
        .DEBOUNCE_FRAMES(3)
    ) u_keypad (
        .clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .col_i(I_SWC), .row_o(O_SWR),
        .key_valid(keypad_valid), .key_code(keypad_code)
    );

    // Controller, games, paint RAM and rendering share the verified 51.2 MHz
    // domain.  Keeping them in one domain avoids direct multi-bit CDC on
    // ui_state, object coordinates and score.
    chapter8_controller #(
        .CLK_HZ(51_200_000),
        .PS2_DEVICE_MODE(PS2_DEVICE_MODE)
    ) u_controller (
        .clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .keypad_valid(keypad_valid), .keypad_code(keypad_code),
        .S1_KEYA(S1_KEYA), .S1_KEYB(S1_KEYB),
        .S1_KEYC(S1_KEYC), .S1_KEYD(S1_KEYD), .S1_KEYP(S1_KEYP),
        .EC_A(EC_A), .EC_B(EC_B), .EC_KEY(EC_KEY),
        .PS2_CLK(PS2_CLK), .PS2_DATA(PS2_DATA),
        .TOUCH_SCL(TOUCH_SCL), .TOUCH_SDA(TOUCH_SDA),
        .TOUCH_INT(TOUCH_INT), .TOUCH_RST(TOUCH_RST),
        .touch_key_press(1'b0),
        .game_exit_request(game_exit_request),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .ui_state(ui_state), .menu_sel(menu_sel),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down), .pointer_click(pointer_click),
        .keyboard_code(keyboard_code),
        .keyboard_extended(keyboard_extended),
        .ec_count(ec_count),
        .touch_x_raw(touch_x_raw), .touch_y_raw(touch_y_raw),
        .ft_flag(ft_flag), .chip_version(chip_version),
        .touch_state(touch_state),
        .touch_coord_valid(touch_coord_valid),
        .game_exit_event(game_exit_event)
    );

    wire game_tick;
    wire tick_1s;
    tick_generator #(.CLK_HZ(51_200_000), .GAME_TICK_HZ(60)) u_ticks (
        .clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .game_tick(game_tick), .tick_1s(tick_1s)
    );

    wire [10:0] px;
    wire [9:0] py;
    wire active_video;
    wire frame_start;
    lcd_timing_1024x600_frame u_lcd_timing (
        .pix_clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .x(px), .y(py), .active_video(active_video),
        .hsync(LCD_HSYNC), .vsync(LCD_VSYNC),
        .frame_start(frame_start)
    );

    // Controller, game logic and pixel sampling share lcd_pix_clk.  Player
    // and game objects are frame-snapshotted inside each slot.
    wire game_pixel_on;
    wire [23:0] game_pixel_rgb;
    wire [15:0] game_score;
    wire [3:0] game_state;

    wire [2:0] ui_state_frame;
    wire [2:0] menu_sel_frame;
    wire [15:0] game_score_frame;
    wire [3:0] game_state_frame;
    wire [25:0] display_state_live =
        {ui_state, menu_sel, game_score, game_state};
    wire [25:0] display_state_frame;

    frame_snapshot_bus #(.WIDTH(26)) u_display_snapshot (
        .clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .frame_start(frame_start),
        .live_bus(display_state_live),
        .frame_bus(display_state_frame)
    );

    assign {ui_state_frame, menu_sel_frame,
            game_score_frame, game_state_frame} = display_state_frame;

    game_system_5slot u_games (
        .clk(lcd_pix_clk), .rst_n(lcd_logic_rst_n),
        .ui_state_control(ui_state), .ui_state_frame(ui_state_frame),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(game_exit_event),
        .event_pause(event_pause),
        .game_tick(game_tick), .tick_1s(tick_1s),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down),
        .pixel_x(px), .pixel_y(py),
        .pixel_on(game_pixel_on), .pixel_rgb(game_pixel_rgb),
        .score(game_score), .game_state(game_state),
        .exit_request(game_exit_request)
    );

    wire pointer_visible = pointer_down || (PS2_DEVICE_MODE == 1);
    wire [23:0] renderer_rgb;

    chapter8_ui_renderer_1024x600 u_renderer (
        .x(px), .y(py), .active_video(active_video),
        .ui_state(ui_state_frame), .menu_sel(menu_sel_frame),
        .keypad_code(keypad_code), .keypad_valid_latched(keypad_valid),
        .keyboard_code(keyboard_code),
        .keyboard_extended(keyboard_extended),
        .ec_count(ec_count),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_visible(pointer_visible), .ft_flag(ft_flag),
        .game_pixel_on(game_pixel_on),
        .game_pixel_rgb(game_pixel_rgb),
        .game_score(game_score_frame), .game_state(game_state_frame),
        .rgb(renderer_rgb)
    );

    reg [23:0] lcd_rgb_reg;
    reg lcd_de_reg;

    always @(posedge lcd_pix_clk or negedge lcd_logic_rst_n) begin
        if (!lcd_logic_rst_n) begin
            lcd_rgb_reg <= 24'h000000;
            lcd_de_reg  <= 1'b0;
        end else begin
            lcd_rgb_reg <= active_video ? renderer_rgb : 24'h000000;
            lcd_de_reg  <= active_video;
        end
    end

    assign LCD_R  = lcd_rgb_reg[23:16];
    assign LCD_G  = lcd_rgb_reg[15:8];
    assign LCD_B  = lcd_rgb_reg[7:0];
    assign LCD_DE = lcd_de_reg;

    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) u_lcd_clk_oddr (
        .Q(LCD_CLK), .C(lcd_pix_clk), .CE(1'b1),
        .D1(1'b0), .D2(1'b1),
        .R(~lcd_logic_rst_n), .S(1'b0)
    );

    assign LCD_BL   = 1'b1;
    assign LCD_nRST = 1'b1;

    // LED4: LCD clock locked; LED3: game/paint page;
    // LED2: paint erase-mode flag (or retained game state bit1);
    // LED1..0: selected menu low bits.  The paint page starts with
    // LED4, LED3 and LED0 lit because menu_sel=5.
    assign led = {
        lcd_clk_locked,
        (ui_state >= 3'd2) && (ui_state <= 3'd6),
        game_state[1],
        menu_sel[1:0]
    };

endmodule
