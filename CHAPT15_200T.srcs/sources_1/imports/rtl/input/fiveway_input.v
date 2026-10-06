`timescale 1ns/1ps

// GX-BIDT verified physical mapping:
//   S1_KEYA = DOWN
//   S1_KEYB = LEFT
//   S1_KEYC = RIGHT
//   S1_KEYD = UP
//   S1_KEYP = CENTER
module fiveway_input #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,

    input  wire key_a,
    input  wire key_b,
    input  wire key_c,
    input  wire key_d,
    input  wire key_p,

    output wire up_level,
    output wire down_level,
    output wire left_level,
    output wire right_level,
    output wire center_level,

    output wire up_press,
    output wire down_press,
    output wire left_press,
    output wire right_press,
    output wire center_press
);

    wire unused_up_release;
    wire unused_down_release;
    wire unused_left_release;
    wire unused_right_release;
    wire unused_center_release;

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS), .ACTIVE_LOW(1))
    u_up (
        .clk(clk), .rst_n(rst_n), .key_in(key_d),
        .key_level(up_level), .press_pulse(up_press),
        .release_pulse(unused_up_release)
    );

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS), .ACTIVE_LOW(1))
    u_down (
        .clk(clk), .rst_n(rst_n), .key_in(key_a),
        .key_level(down_level), .press_pulse(down_press),
        .release_pulse(unused_down_release)
    );

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS), .ACTIVE_LOW(1))
    u_left (
        .clk(clk), .rst_n(rst_n), .key_in(key_b),
        .key_level(left_level), .press_pulse(left_press),
        .release_pulse(unused_left_release)
    );

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS), .ACTIVE_LOW(1))
    u_right (
        .clk(clk), .rst_n(rst_n), .key_in(key_c),
        .key_level(right_level), .press_pulse(right_press),
        .release_pulse(unused_right_release)
    );

    debounce_event #(.CLK_HZ(CLK_HZ), .DEBOUNCE_MS(DEBOUNCE_MS), .ACTIVE_LOW(1))
    u_center (
        .clk(clk), .rst_n(rst_n), .key_in(key_p),
        .key_level(center_level), .press_pulse(center_press),
        .release_pulse(unused_center_release)
    );

endmodule
