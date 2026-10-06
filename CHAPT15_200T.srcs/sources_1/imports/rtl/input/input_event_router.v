`timescale 1ns/1ps

// Chapter 7 unified event interface.
// UI/game logic consumes these standardized events instead of raw sources.
module input_event_router(
    // Five-way
    input wire five_up_press,
    input wire five_down_press,
    input wire five_left_press,
    input wire five_right_press,
    input wire five_center_press,

    // EC11
    input wire ec_key_press,

    // Keyboard
    input wire keyboard_up_press,
    input wire keyboard_down_press,
    input wire keyboard_left_press,
    input wire keyboard_right_press,
    input wire keyboard_enter_press,
    input wire keyboard_esc_press,
    input wire keyboard_pause_press,

    // Mouse
    input wire mouse_left_press,
    input wire mouse_right_press,

    // Capacitive touch
    input wire touch_click,
    input wire touch_swipe_up,
    input wire touch_swipe_down,
    input wire touch_swipe_left,
    input wire touch_swipe_right,

    // 4x4 keypad (optional in the LCD-integrated top because board muxing
    // may need a different A-group selection)
    input wire       keypad_valid,
    input wire [3:0] keypad_code,

    // Touch-key optional source
    input wire touch_key_press,

    output wire event_up,
    output wire event_down,
    output wire event_left,
    output wire event_right,
    output wire event_ok,
    output wire event_back,
    output wire event_pause
);

    // GX-BIDT Chapter-4 hardware-verified raw matrix codes:
    // physical 2/8/4/6/5/F -> raw E/4/8/A/9/3.
    assign event_up =
        five_up_press ||
        keyboard_up_press ||
        touch_swipe_up ||
        (keypad_valid && keypad_code == 4'hE);

    assign event_down =
        five_down_press ||
        keyboard_down_press ||
        touch_swipe_down ||
        (keypad_valid && keypad_code == 4'h4);

    assign event_left =
        five_left_press ||
        keyboard_left_press ||
        touch_swipe_left ||
        (keypad_valid && keypad_code == 4'h8);

    assign event_right =
        five_right_press ||
        keyboard_right_press ||
        touch_swipe_right ||
        (keypad_valid && keypad_code == 4'hA);

    assign event_ok =
        five_center_press ||
        ec_key_press ||
        keyboard_enter_press ||
        mouse_left_press ||
        touch_click ||
        (keypad_valid && keypad_code == 4'h9);

    assign event_back =
        touch_key_press ||
        keyboard_esc_press ||
        mouse_right_press ||
        (keypad_valid && keypad_code == 4'h3);

    assign event_pause =
        keyboard_pause_press;

endmodule
