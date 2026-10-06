`timescale 1ns/1ps

// Shared one-cycle timing pulses for all Chapter-8 game slots.
module tick_generator #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer GAME_TICK_HZ = 60
)(
    input  wire clk,
    input  wire rst_n,
    output reg  game_tick,
    output reg  tick_1s
);

    localparam integer GAME_DIV = CLK_HZ / GAME_TICK_HZ;
    localparam integer SEC_DIV  = CLK_HZ;

    reg [31:0] game_count;
    reg [31:0] sec_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            game_count <= 32'd0;
            sec_count  <= 32'd0;
            game_tick  <= 1'b0;
            tick_1s    <= 1'b0;
        end else begin
            game_tick <= 1'b0;
            tick_1s   <= 1'b0;

            if (game_count >= GAME_DIV - 1) begin
                game_count <= 32'd0;
                game_tick  <= 1'b1;
            end else begin
                game_count <= game_count + 32'd1;
            end

            if (sec_count >= SEC_DIV - 1) begin
                sec_count <= 32'd0;
                tick_1s   <= 1'b1;
            end else begin
                sec_count <= sec_count + 32'd1;
            end
        end
    end

endmodule
