`timescale 1ns/1ps

// Chapter-7 input controller plus the Chapter-8 system FSM.
module chapter8_controller #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer PS2_DEVICE_MODE = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       keypad_valid,
    input  wire [3:0] keypad_code,
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
    input  wire touch_key_press,
    input  wire game_exit_request,
    output wire event_up,
    output wire event_down,
    output wire event_left,
    output wire event_right,
    output wire event_ok,
    output wire event_back,
    output wire event_pause,
    output wire [2:0] ui_state,
    output wire [2:0] menu_sel,
    output wire [10:0] pointer_x,
    output wire [9:0]  pointer_y,
    output wire pointer_down,
    output wire pointer_click,
    output wire [7:0] keyboard_code,
    output wire keyboard_extended,
    output wire [4:0] ec_count,
    output wire [15:0] touch_x_raw,
    output wire [15:0] touch_y_raw,
    output wire ft_flag,
    output wire [15:0] chip_version,
    output wire [6:0] touch_state,
    output wire touch_coord_valid,
    output wire game_exit_event
);

    wire [2:0] legacy_ui_state_unused;
    wire [2:0] legacy_menu_sel_unused;
    wire legacy_paused_unused;

    chapter7_controller #(
        .CLK_HZ(CLK_HZ),
        .PS2_DEVICE_MODE(PS2_DEVICE_MODE)
    ) u_input_controller (
        .clk(clk), .rst_n(rst_n),
        .keypad_valid(keypad_valid), .keypad_code(keypad_code),
        .S1_KEYA(S1_KEYA), .S1_KEYB(S1_KEYB),
        .S1_KEYC(S1_KEYC), .S1_KEYD(S1_KEYD), .S1_KEYP(S1_KEYP),
        .EC_A(EC_A), .EC_B(EC_B), .EC_KEY(EC_KEY),
        .PS2_CLK(PS2_CLK), .PS2_DATA(PS2_DATA),
        .TOUCH_SCL(TOUCH_SCL), .TOUCH_SDA(TOUCH_SDA),
        .TOUCH_INT(TOUCH_INT), .TOUCH_RST(TOUCH_RST),
        .touch_key_press(touch_key_press),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .ui_state(legacy_ui_state_unused),
        .menu_sel(legacy_menu_sel_unused),
        .paused(legacy_paused_unused),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down), .pointer_click(pointer_click),
        .keyboard_code(keyboard_code),
        .keyboard_extended(keyboard_extended),
        .ec_count(ec_count),
        .touch_x_raw(touch_x_raw), .touch_y_raw(touch_y_raw),
        .ft_flag(ft_flag), .chip_version(chip_version),
        .touch_state(touch_state),
        .touch_coord_valid(touch_coord_valid)
    );

    wire button_hit_unused;
    wire button_click;
    wire [2:0] button_index;

    touch_button_hit_1024x600 u_button_hit (
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_click(pointer_click),
        .button_hit(button_hit_unused),
        .button_click(button_click),
        .button_index(button_index)
    );

    ui_fsm_chapter8 u_ui_fsm (
        .clk(clk), .rst_n(rst_n),
        .event_up(event_up), .event_down(event_down),
        .event_ok(event_ok), .event_back(event_back),
        .touch_button_valid(button_click),
        .touch_button_index(button_index),
        .game_exit_request(game_exit_request),
        .ui_state(ui_state), .menu_sel(menu_sel)
    );

    // Game modules consume Back directly as their standardized exit request.
    assign game_exit_event = event_back;

endmodule
