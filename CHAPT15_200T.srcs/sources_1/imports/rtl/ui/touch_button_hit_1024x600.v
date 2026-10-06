`timescale 1ns/1ps

module touch_button_hit_1024x600(
    input  wire [10:0] pointer_x,
    input  wire [9:0]  pointer_y,
    input  wire        pointer_click,

    output reg         button_hit,
    output reg         button_click,
    output reg  [2:0]  button_index
);

    // Seven menu buttons adapted from the tutorial's 800x480 concept
    // to the verified 1024x600 panel.
    localparam integer X0 = 140;
    localparam integer X1 = 884;
    localparam integer Y0 = 40;
    localparam integer H  = 58;
    localparam integer G  = 18;

    integer idx;
    integer top_y;
    integer bot_y;

    always @(*) begin
        button_hit   = 1'b0;
        button_index = 3'd0;

        if ((pointer_x >= X0) && (pointer_x < X1)) begin
            for (idx = 0; idx < 7; idx = idx + 1) begin
                top_y = Y0 + idx * (H + G);
                bot_y = top_y + H;

                if ((pointer_y >= top_y) && (pointer_y < bot_y)) begin
                    button_hit   = 1'b1;
                    button_index = idx[2:0];
                end
            end
        end

        button_click = pointer_click && button_hit;
    end

endmodule
