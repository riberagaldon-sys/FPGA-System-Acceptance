`timescale 1ns/1ps

module chapter7_controller #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer PS2_DEVICE_MODE = 0   // 0 keyboard, 1 mouse
)(
    input  wire       clk,
    input  wire       rst_n,

    // Optional 4x4 keypad event source
    input  wire       keypad_valid,
    input  wire [3:0] keypad_code,

    // Five-way + EC11
    input  wire S1_KEYA,
    input  wire S1_KEYB,
    input  wire S1_KEYC,
    input  wire S1_KEYD,
    input  wire S1_KEYP,
    input  wire EC_A,
    input  wire EC_B,
    input  wire EC_KEY,

    // PS/2 open drain
    inout  wire PS2_CLK,
    inout  wire PS2_DATA,

    // Capacitive touch
    output wire TOUCH_SCL,
    inout  wire TOUCH_SDA,
    inout  wire TOUCH_INT,
    output wire TOUCH_RST,

    // Optional touch-key pulse (tie 0 where board mux route is not selected)
    input wire touch_key_press,

    // Unified events
    output wire event_up,
    output wire event_down,
    output wire event_left,
    output wire event_right,
    output wire event_ok,
    output wire event_back,
    output wire event_pause,

    // UI
    output wire [2:0] ui_state,
    output wire [2:0] menu_sel,
    output wire       paused,

    // Pointer
    output wire [10:0] pointer_x,
    output wire [9:0]  pointer_y,
    output wire        pointer_down,
    output wire        pointer_click,

    // Monitor outputs
    output wire [7:0]  keyboard_code,
    output wire        keyboard_extended,
    output wire [4:0]  ec_count,
    output wire [15:0] touch_x_raw,
    output wire [15:0] touch_y_raw,
    output wire        ft_flag,
    output wire [15:0] chip_version,
    output wire [6:0]  touch_state,
    output wire        touch_coord_valid
);

    // --------------------------------------------------------------
    // Five-way
    // --------------------------------------------------------------
    wire five_up_level, five_down_level, five_left_level, five_right_level, five_center_level;
    wire five_up_press, five_down_press, five_left_press, five_right_press, five_center_press;

    fiveway_input #(.CLK_HZ(CLK_HZ)) u_fiveway (
        .clk(clk), .rst_n(rst_n),
        .key_a(S1_KEYA), .key_b(S1_KEYB), .key_c(S1_KEYC),
        .key_d(S1_KEYD), .key_p(S1_KEYP),
        .up_level(five_up_level), .down_level(five_down_level),
        .left_level(five_left_level), .right_level(five_right_level),
        .center_level(five_center_level),
        .up_press(five_up_press), .down_press(five_down_press),
        .left_press(five_left_press), .right_press(five_right_press),
        .center_press(five_center_press)
    );

    // --------------------------------------------------------------
    // EC11 compatibility event + clear key
    // --------------------------------------------------------------
    wire ec_step;
    wire ec_step_dir;
    wire ec_key_level;
    wire ec_key_press;
    wire ec_key_release_unused;

    ec11_compat #(.CLK_HZ(CLK_HZ), .LOCKOUT_MS(300)) u_ec_compat (
        .clk(clk),
        .rst_n(rst_n && !ec_key_level),
        .ec_a(EC_A),
        .ec_b(EC_B),
        .step_pulse(ec_step),
        .step_dir(ec_step_dir)
    );

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(20), .ACTIVE_LOW(1))
    u_ec_key (
        .clk(clk), .rst_n(rst_n), .key_in(EC_KEY),
        .key_level(ec_key_level), .press_pulse(ec_key_press),
        .release_pulse(ec_key_release_unused)
    );

    reg [4:0] ec_count_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ec_count_reg <= 5'd0;
        else if (ec_key_press)
            ec_count_reg <= 5'd0;
        else if (ec_step)
            ec_count_reg <= ec_count_reg + 5'd1;
    end
    assign ec_count = ec_count_reg;

    // --------------------------------------------------------------
    // PS/2 shared open-drain interface
    // --------------------------------------------------------------
    wire ps2_clk_in  = PS2_CLK;
    wire ps2_data_in = PS2_DATA;
    wire ps2_clk_drive_low;
    wire ps2_data_drive_low;

    assign PS2_CLK  = ps2_clk_drive_low  ? 1'b0 : 1'bz;
    assign PS2_DATA = ps2_data_drive_low ? 1'b0 : 1'bz;

    wire kb_up, kb_down, kb_left, kb_right, kb_ok, kb_back, kb_pause;
    wire [7:0] keyboard_code_i;
    wire keyboard_extended_i;

    wire mouse_left_press;
    wire mouse_right_press;
    wire [10:0] mouse_x;
    wire [9:0]  mouse_y;
    wire mouse_packet_valid;
    wire [2:0] mouse_buttons;

    generate
        if (PS2_DEVICE_MODE == 0) begin : g_keyboard
            wire [7:0] scan_code;
            wire scan_valid;
            wire frame_error;
            wire key_press;
            wire key_release;

            assign ps2_clk_drive_low  = 1'b0;
            assign ps2_data_drive_low = 1'b0;
            assign mouse_left_press   = 1'b0;
            assign mouse_right_press  = 1'b0;
            assign mouse_x            = 11'd512;
            assign mouse_y            = 10'd300;
            assign mouse_packet_valid = 1'b0;
            assign mouse_buttons      = 3'b000;

            ps2_rx #(.CLK_HZ(CLK_HZ), .TIMEOUT_US(2000)) u_ps2_rx (
                .clk(clk), .rst_n(rst_n),
                .ps2_clk(ps2_clk_in), .ps2_data(ps2_data_in),
                .data_byte(scan_code), .data_valid(scan_valid),
                .frame_error(frame_error)
            );

            ps2_keyboard_decoder u_keyboard_decoder (
                .clk(clk), .rst_n(rst_n),
                .scan_code(scan_code), .scan_valid(scan_valid),
                .key_press(key_press), .key_release(key_release),
                .key_code(keyboard_code_i),
                .extended(keyboard_extended_i)
            );

            keyboard_event_mapper u_keyboard_mapper (
                .key_press(key_press), .key_release(key_release),
                .key_code(keyboard_code_i), .extended(keyboard_extended_i),
                .event_up(kb_up), .event_down(kb_down),
                .event_left(kb_left), .event_right(kb_right),
                .event_ok(kb_ok), .event_back(kb_back),
                .event_pause(kb_pause)
            );
        end else begin : g_mouse
            wire tx_start;
            wire [7:0] tx_byte;
            wire tx_busy, tx_done, tx_ack_ok, tx_error;
            wire [7:0] rx_byte;
            wire rx_valid, rx_frame_error;
            wire mouse_ready, init_error;
            wire signed [8:0] dx;
            wire signed [8:0] dy;
            wire mouse_middle_press_unused;

            assign keyboard_code_i     = 8'd0;
            assign keyboard_extended_i = 1'b0;
            assign kb_up = 1'b0;
            assign kb_down = 1'b0;
            assign kb_left = 1'b0;
            assign kb_right = 1'b0;
            assign kb_ok = 1'b0;
            assign kb_back = 1'b0;
            assign kb_pause = 1'b0;

            ps2_host_tx #(.CLK_HZ(CLK_HZ)) u_ps2_host_tx (
                .clk(clk), .rst_n(rst_n),
                .start(tx_start), .tx_byte(tx_byte),
                .ps2_clk_in(ps2_clk_in), .ps2_data_in(ps2_data_in),
                .ps2_clk_drive_low(ps2_clk_drive_low),
                .ps2_data_drive_low(ps2_data_drive_low),
                .busy(tx_busy), .done(tx_done), .ack_ok(tx_ack_ok),
                .tx_error(tx_error)
            );

            ps2_rx #(.CLK_HZ(CLK_HZ), .TIMEOUT_US(2000)) u_ps2_rx (
                .clk(clk), .rst_n(rst_n && !tx_busy),
                .ps2_clk(ps2_clk_in), .ps2_data(ps2_data_in),
                .data_byte(rx_byte), .data_valid(rx_valid),
                .frame_error(rx_frame_error)
            );

            ps2_mouse_init #(.CLK_HZ(CLK_HZ)) u_mouse_init (
                .clk(clk), .rst_n(rst_n),
                .tx_start(tx_start), .tx_byte(tx_byte),
                .tx_busy(tx_busy), .tx_done(tx_done),
                .tx_ack_ok(tx_ack_ok), .tx_error(tx_error),
                .rx_byte(rx_byte), .rx_valid(rx_valid),
                .mouse_ready(mouse_ready), .init_error(init_error)
            );

            ps2_mouse_packet #(
                .X_MAX(1023), .Y_MAX(599),
                .X_INIT(512), .Y_INIT(300),
                .MAX_DELTA(64)
            ) u_mouse_packet (
                .clk(clk), .rst_n(rst_n), .enable(mouse_ready),
                .data_byte(rx_byte), .data_valid(rx_valid),
                .frame_error(rx_frame_error),
                .packet_valid(mouse_packet_valid),
                .buttons(mouse_buttons), .dx(dx), .dy(dy),
                .mouse_x(mouse_x), .mouse_y(mouse_y)
            );

            mouse_event_mapper u_mouse_events (
                .clk(clk), .rst_n(rst_n),
                .packet_valid(mouse_packet_valid), .buttons(mouse_buttons),
                .dx(dx), .dy(dy),
                .left_press(mouse_left_press),
                .right_press(mouse_right_press),
                .middle_press(mouse_middle_press_unused)
            );
        end
    endgenerate

    assign keyboard_code     = keyboard_code_i;
    assign keyboard_extended = keyboard_extended_i;

    // --------------------------------------------------------------
    // Capacitive touch: reuse Chapter-6 Chapter-34 driver
    // --------------------------------------------------------------
    wire [31:0] touch_data;
    wire dbg_i2c_ack, dbg_i2c_done, dbg_once_byte_done;
    wire [7:0] dbg_i2c_data_r;
    wire touch_valid_raw;

    touch_top_ch34 #(
        .CLK_FREQ(CLK_HZ),
        .I2C_FREQ(250_000),
        .REG_NUM_WID(8)
    ) u_touch (
        .clk(clk), .rst_n(rst_n),
        .touch_rst_n(TOUCH_RST),
        .touch_int(TOUCH_INT),
        .touch_scl(TOUCH_SCL),
        .touch_sda(TOUCH_SDA),
        .data(touch_data),
        .dbg_i2c_ack(dbg_i2c_ack),
        .dbg_i2c_done(dbg_i2c_done),
        .dbg_once_byte_done(dbg_once_byte_done),
        .dbg_i2c_data_r(dbg_i2c_data_r),
        .dbg_touch_valid(touch_valid_raw),
        .dbg_ft_flag(ft_flag),
        .dbg_chip_version(chip_version),
        .dbg_x(touch_x_raw),
        .dbg_y(touch_y_raw),
        .dbg_state(touch_state)
    );

    wire [10:0] touch_pointer_x;
    wire [9:0]  touch_pointer_y;
    wire touch_pointer_down;
    wire touch_pointer_click;
    wire touch_swipe_up, touch_swipe_down, touch_swipe_left, touch_swipe_right;
    wire coord_update_pulse;

    touch_event_adapter u_touch_adapter (
        .clk(clk), .rst_n(rst_n),
        .touch_valid_raw(touch_valid_raw),
        .touch_x_raw(touch_x_raw), .touch_y_raw(touch_y_raw),
        .touch_state(touch_state),
        .pointer_x(touch_pointer_x), .pointer_y(touch_pointer_y),
        .pointer_down(touch_pointer_down),
        .pointer_click(touch_pointer_click),
        .swipe_up(touch_swipe_up), .swipe_down(touch_swipe_down),
        .swipe_left(touch_swipe_left), .swipe_right(touch_swipe_right),
        .coord_update_pulse(coord_update_pulse)
    );

    assign pointer_x =
        (touch_pointer_down || touch_pointer_click) ?
        touch_pointer_x : mouse_x;
    assign pointer_y =
        (touch_pointer_down || touch_pointer_click) ?
        touch_pointer_y : mouse_y;
    // Only the mouse LEFT button is a draw/press level.  Right remains the
    // Back event and the middle button must not create paint strokes.
    assign pointer_down =
        touch_pointer_down || mouse_buttons[0];
    assign pointer_click =
        touch_pointer_click || mouse_left_press;

    assign touch_coord_valid = coord_update_pulse;

    // --------------------------------------------------------------
    // Unified events
    // --------------------------------------------------------------
    wire event_left_base;
    wire event_right_base;

    input_event_router u_event_router (
        .five_up_press(five_up_press),
        .five_down_press(five_down_press),
        .five_left_press(five_left_press),
        .five_right_press(five_right_press),
        .five_center_press(five_center_press),
        .ec_key_press(ec_key_press),

        .keyboard_up_press(kb_up),
        .keyboard_down_press(kb_down),
        .keyboard_left_press(kb_left),
        .keyboard_right_press(kb_right),
        .keyboard_enter_press(kb_ok),
        .keyboard_esc_press(kb_back),
        .keyboard_pause_press(kb_pause),

        .mouse_left_press(mouse_left_press),
        .mouse_right_press(mouse_right_press),

        .touch_click(touch_pointer_click),
        .touch_swipe_up(touch_swipe_up),
        .touch_swipe_down(touch_swipe_down),
        .touch_swipe_left(touch_swipe_left),
        .touch_swipe_right(touch_swipe_right),

        .keypad_valid(keypad_valid),
        .keypad_code(keypad_code),
        .touch_key_press(touch_key_press),

        .event_up(event_up), .event_down(event_down),
        .event_left(event_left_base), .event_right(event_right_base),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause)
    );

    // GX-BIDT实物方向：ec_step_dir=0对应顺时针。
    // 因此顺时针映射为“右”，逆时针映射为“左”。
    // 只交换EC11附加事件，不影响五向键和键盘的左右方向。
    assign event_left  = event_left_base  || (ec_step &&  ec_step_dir);
    assign event_right = event_right_base || (ec_step && !ec_step_dir);

    // --------------------------------------------------------------
    // Touch menu buttons + UI FSM
    // --------------------------------------------------------------
    wire button_hit;
    wire button_click;
    wire [2:0] button_index;

    touch_button_hit_1024x600 u_button_hit (
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_click(pointer_click),
        .button_hit(button_hit), .button_click(button_click),
        .button_index(button_index)
    );

    ui_fsm u_ui_fsm (
        .clk(clk), .rst_n(rst_n),
        .event_up(event_up), .event_down(event_down),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .touch_button_valid(button_click),
        .touch_button_index(button_index),
        .ui_state(ui_state), .menu_sel(menu_sel), .paused(paused)
    );

endmodule
