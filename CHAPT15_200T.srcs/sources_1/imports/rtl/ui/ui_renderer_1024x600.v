`timescale 1ns/1ps

module ui_renderer_1024x600(
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        active_video,

    input  wire [2:0]  ui_state,
    input  wire [2:0]  menu_sel,
    input  wire        paused,

    input  wire [3:0]  keypad_code,
    input  wire        keypad_valid_latched,
    input  wire [7:0]  keyboard_code,
    input  wire        keyboard_extended,
    input  wire [4:0]  ec_count,
    input  wire [15:0] touch_x,
    input  wire [15:0] touch_y,
    input  wire        touch_down,
    input  wire        ft_flag,

    output reg  [23:0] rgb
);

    localparam [23:0]
        C_BLACK  = 24'h101820,
        C_WHITE  = 24'hF4F4F4,
        C_BLUE   = 24'h2457A7,
        C_GREEN  = 24'h2D8C5A,
        C_RED    = 24'hA83A3A,
        C_YELLOW = 24'hE3B341,
        C_GRAY   = 24'h5E6870,
        C_CYAN   = 24'h2A9DAD,
        C_PURPLE = 24'h6D4AA5;

    integer idx;
    integer top_y;
    integer bot_y;
    reg [23:0] page_color;

    wire crosshair =
        touch_down &&
        (((x >= touch_x[10:0] - 11'd10) && (x <= touch_x[10:0] + 11'd10) &&
          (y == touch_y[9:0])) ||
         ((y >= touch_y[9:0] - 10'd10) && (y <= touch_y[9:0] + 10'd10) &&
          (x == touch_x[10:0])));

    always @(*) begin
        page_color = C_BLACK;

        case (ui_state)
            3'd1: page_color = C_BLUE;   // input monitor
            3'd2: page_color = C_GREEN;  // treasure
            3'd3: page_color = C_PURPLE; // snake
            3'd4: page_color = C_CYAN;   // maze
            3'd5: page_color = C_RED;    // breakout
            3'd6: page_color = 24'h202020;// paint
            3'd7: page_color = C_GRAY;   // info
            default: page_color = C_BLACK;
        endcase

        if (!active_video) begin
            rgb = 24'h000000;
        end else if (ui_state == 3'd0) begin
            // HOME: seven large touch/menu buttons.
            rgb = 24'h17212B;

            for (idx = 0; idx < 7; idx = idx + 1) begin
                top_y = 40 + idx * 76;
                bot_y = top_y + 58;

                if ((x >= 140) && (x < 884) &&
                    (y >= top_y) && (y < bot_y)) begin
                    if (menu_sel == idx[2:0])
                        rgb = C_YELLOW;
                    else
                        rgb = (idx[0]) ? C_BLUE : C_GREEN;
                end
            end
        end else if (ui_state == 3'd1) begin
            // INPUT monitor: deliberately graphic (no font ROM dependency).
            rgb = 24'h10233D;

            // Keypad code bar.
            if ((y >= 60) && (y < 110) && (x < (keypad_code * 64 + 64)))
                rgb = C_YELLOW;

            // EC cumulative count bar.
            if ((y >= 150) && (y < 200) && (x < (ec_count * 28 + 28)))
                rgb = C_GREEN;

            // Keyboard code lower 7 bits bar.
            if ((y >= 240) && (y < 290) && (x < ({3'b000,keyboard_code[6:0]} * 6 + 6)))
                rgb = keyboard_extended ? C_PURPLE : C_CYAN;

            // Touch controller family indicator.
            if ((y >= 330) && (y < 380) && (x >= 60) && (x < 300))
                rgb = ft_flag ? C_GREEN : C_BLUE;

            // Touch X/Y quadrant reference.
            if ((x == 512) || (y == 300))
                rgb = 24'h667788;

            if (crosshair)
                rgb = C_WHITE;

            if (keypad_valid_latched && (x >= 900) && (y < 80))
                rgb = C_YELLOW;
        end else begin
            rgb = page_color;

            // Common back-guide border.
            if ((x < 8) || (x > 1015) || (y < 8) || (y > 591))
                rgb = C_WHITE;

            if (paused && (x >= 400) && (x < 624) && (y >= 260) && (y < 340))
                rgb = C_YELLOW;

            if (crosshair)
                rgb = C_WHITE;
        end
    end

endmodule
