`timescale 1ns/1ps

module keyboard_event_mapper(
    input  wire       key_press,
    input  wire       key_release,
    input  wire [7:0] key_code,
    input  wire       extended,

    output wire event_up,
    output wire event_down,
    output wire event_left,
    output wire event_right,
    output wire event_ok,
    output wire event_back,
    output wire event_pause
);

    // PS/2 Set-2:
    // W=1D A=1C S=1B D=23
    // Enter=5A Esc=76 Space=29
    // Extended arrows: E0 75/72/6B/74
    assign event_up =
        key_press && ((!extended && key_code == 8'h1D) ||
                      ( extended && key_code == 8'h75));

    assign event_down =
        key_press && ((!extended && key_code == 8'h1B) ||
                      ( extended && key_code == 8'h72));

    assign event_left =
        key_press && ((!extended && key_code == 8'h1C) ||
                      ( extended && key_code == 8'h6B));

    assign event_right =
        key_press && ((!extended && key_code == 8'h23) ||
                      ( extended && key_code == 8'h74));

    assign event_ok =
        key_press && !extended && (key_code == 8'h5A);

    assign event_back =
        key_press && !extended && (key_code == 8'h76);

    // Use release instead of make so typematic repeats cannot toggle pause
    // several times while the space bar is held down.
    assign event_pause =
        key_release && !extended && (key_code == 8'h29);

endmodule
