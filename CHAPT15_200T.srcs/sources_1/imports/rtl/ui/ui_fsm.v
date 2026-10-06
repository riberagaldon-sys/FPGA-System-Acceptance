`timescale 1ns/1ps

module ui_fsm(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       event_up,
    input  wire       event_down,
    input  wire       event_ok,
    input  wire       event_back,
    input  wire       event_pause,

    input  wire       touch_button_valid,
    input  wire [2:0] touch_button_index,

    output reg  [2:0] ui_state,
    output reg  [2:0] menu_sel,
    output reg        paused
);

    localparam [2:0]
        UI_HOME     = 3'd0,
        UI_INPUT    = 3'd1,
        UI_TREASURE = 3'd2,
        UI_SNAKE    = 3'd3,
        UI_MAZE     = 3'd4,
        UI_BREAKOUT = 3'd5,
        UI_PAINT    = 3'd6,
        UI_INFO     = 3'd7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_state <= UI_HOME;
            menu_sel <= 3'd0;
            paused   <= 1'b0;
        end else begin
            if (event_pause)
                paused <= ~paused;

            if (ui_state == UI_HOME) begin
                if (touch_button_valid) begin
                    ui_state <= touch_button_index + 3'd1;
                    menu_sel <= touch_button_index;
                end else if (event_up) begin
                    if (menu_sel == 3'd0)
                        menu_sel <= 3'd6;
                    else
                        menu_sel <= menu_sel - 3'd1;
                end else if (event_down) begin
                    if (menu_sel == 3'd6)
                        menu_sel <= 3'd0;
                    else
                        menu_sel <= menu_sel + 3'd1;
                end else if (event_ok) begin
                    ui_state <= menu_sel + 3'd1;
                end
            end else begin
                if (event_back)
                    ui_state <= UI_HOME;
            end
        end
    end

endmodule
