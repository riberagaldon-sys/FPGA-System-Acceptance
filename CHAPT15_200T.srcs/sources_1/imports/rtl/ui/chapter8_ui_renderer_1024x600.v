`timescale 1ns/1ps

// Chapter-8 system renderer.  HOME/Input/Info remain system-owned; states
// 2..6 are supplied by the selected unified game slot.
module chapter8_ui_renderer_1024x600(
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        active_video,
    input  wire [2:0]  ui_state,
    input  wire [2:0]  menu_sel,
    input  wire [3:0]  keypad_code,
    input  wire        keypad_valid_latched,
    input  wire [7:0]  keyboard_code,
    input  wire        keyboard_extended,
    input  wire [4:0]  ec_count,
    input  wire [10:0] pointer_x,
    input  wire [9:0]  pointer_y,
    input  wire        pointer_visible,
    input  wire        ft_flag,
    input  wire        game_pixel_on,
    input  wire [23:0] game_pixel_rgb,
    input  wire [15:0] game_score,
    input  wire [3:0]  game_state,
    output reg  [23:0] rgb
);

    localparam [23:0]
        C_WHITE  = 24'hF4F4F4,
        C_BLUE   = 24'h2457A7,
        C_GREEN  = 24'h2D8C5A,
        C_YELLOW = 24'hE3B341,
        C_GRAY   = 24'h5E6870,
        C_CYAN   = 24'h2A9DAD,
        C_PURPLE = 24'h6D4AA5;

    integer idx;
    integer top_y;
    integer bot_y;

    wire horizontal_crosshair =
        ((x + 11'd10) >= pointer_x) &&
        (x <= pointer_x + 11'd10) &&
        (y == pointer_y);
    wire vertical_crosshair =
        ((y + 10'd10) >= pointer_y) &&
        (y <= pointer_y + 10'd10) &&
        (x == pointer_x);
    wire crosshair =
        pointer_visible && (horizontal_crosshair || vertical_crosshair);

    always @(*) begin
        if (!active_video) begin
            rgb = 24'h000000;
        end else if (ui_state == 3'd0) begin
            rgb = 24'h17212B;

            for (idx = 0; idx < 7; idx = idx + 1) begin
                top_y = 40 + idx * 76;
                bot_y = top_y + 58;
                if ((x >= 140) && (x < 884) &&
                    (y >= top_y) && (y < bot_y)) begin
                    if (menu_sel == idx)
                        rgb = C_YELLOW;
                    else
                        rgb = idx[0] ? C_BLUE : C_GREEN;
                end
            end

            if (crosshair)
                rgb = C_WHITE;
        end else if (ui_state == 3'd1) begin
            rgb = 24'h10233D;

            if ((y >= 60) && (y < 110) && (x < (keypad_code * 64 + 64)))
                rgb = C_YELLOW;
            if ((y >= 150) && (y < 200) && (x < (ec_count * 28 + 28)))
                rgb = C_GREEN;
            if ((y >= 240) && (y < 290) &&
                (x < ({3'b000,keyboard_code[6:0]} * 6 + 6)))
                rgb = keyboard_extended ? C_PURPLE : C_CYAN;
            if ((y >= 330) && (y < 380) && (x >= 60) && (x < 300))
                rgb = ft_flag ? C_GREEN : C_BLUE;
            if ((x == 512) || (y == 300))
                rgb = 24'h667788;
            if (keypad_valid_latched && (x >= 900) && (y < 80))
                rgb = C_YELLOW;
            if (crosshair)
                rgb = C_WHITE;
        end else if ((ui_state >= 3'd2) && (ui_state <= 3'd6)) begin
            rgb = game_pixel_on ? game_pixel_rgb : 24'h101820;

            // Slots 1..4 retain the system diagnostic score/state strips.
            // Slot 5 is the paint board and owns its full toolbar area.
            if (ui_state != 3'd6) begin
                if ((y >= 10'd4) && (y < 10'd12) &&
                    (x < ({5'd0, game_score[5:0]} << 3)))
                    rgb = C_YELLOW;
                if ((y >= 10'd48) && (y < 10'd56) &&
                    (x < ({7'd0, game_state} << 5)))
                    rgb = C_WHITE;
            end

            if (crosshair)
                rgb = C_WHITE;
        end else begin
            // System information page.
            rgb = C_GRAY;
            if ((x < 8) || (x > 1015) || (y < 8) || (y > 591))
                rgb = C_WHITE;
            if ((x >= 128) && (x < 896) &&
                (y >= 128) && (y < 472))
                rgb = 24'h34434D;
            if (crosshair)
                rgb = C_WHITE;
        end
    end

endmodule
