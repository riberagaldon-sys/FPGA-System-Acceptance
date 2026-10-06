`timescale 1ns/1ps

module ui_fsm_chapter8(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       event_up,
    input  wire       event_down,
    input  wire       event_ok,
    input  wire       event_back,
    input  wire       touch_button_valid,
    input  wire [2:0] touch_button_index,
    input  wire       game_exit_request,
    output reg  [2:0] ui_state,
    output reg  [2:0] menu_sel
);

    localparam [2:0] UI_HOME = 3'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_state <= UI_HOME;
            menu_sel <= 3'd0;
        end else if (ui_state == UI_HOME) begin
            if (touch_button_valid) begin
                ui_state <= touch_button_index + 3'd1;
                menu_sel <= touch_button_index;
            end else if (event_up) begin
                menu_sel <= (menu_sel == 3'd0) ? 3'd6 : menu_sel - 3'd1;
            end else if (event_down) begin
                menu_sel <= (menu_sel == 3'd6) ? 3'd0 : menu_sel + 3'd1;
            end else if (event_ok) begin
                ui_state <= menu_sel + 3'd1;
            end
        end else if (event_back || game_exit_request) begin
            ui_state <= UI_HOME;
        end
    end

endmodule
