`timescale 1ns/1ps

module lcd_timing_1024x600(
    input  wire        pix_clk,
    input  wire        rst_n,

    output reg  [10:0] x,
    output reg  [9:0]  y,
    output wire        active_video,
    output wire        hsync,
    output wire        vsync
);
    // 50 MHz timing used by the previous GX-BIDT 1024x600 project.
    // Total: H=1344, V=635.
    localparam integer H_SYNC   = 20;
    localparam integer H_BP     = 140;
    localparam integer H_ACTIVE = 1024;
    localparam integer H_FP     = 160;
    localparam integer H_TOTAL  = H_SYNC + H_BP + H_ACTIVE + H_FP;

    localparam integer V_SYNC   = 3;
    localparam integer V_BP     = 20;
    localparam integer V_ACTIVE = 600;
    localparam integer V_FP     = 12;
    localparam integer V_TOTAL  = V_SYNC + V_BP + V_ACTIVE + V_FP;

    reg [10:0] h_count;
    reg [9:0]  v_count;

    wire h_active =
        (h_count >= H_SYNC + H_BP) &&
        (h_count <  H_SYNC + H_BP + H_ACTIVE);

    wire v_active =
        (v_count >= V_SYNC + V_BP) &&
        (v_count <  V_SYNC + V_BP + V_ACTIVE);

    assign hsync = (h_count < H_SYNC) ? 1'b0 : 1'b1;
    assign vsync = (v_count < V_SYNC) ? 1'b0 : 1'b1;
    assign active_video = h_active && v_active;

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 11'd0;
            v_count <= 10'd0;
            x <= 11'd0;
            y <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end

            if (h_active)
                x <= h_count - (H_SYNC + H_BP);
            else
                x <= 11'd0;

            if (v_active)
                y <= v_count - (V_SYNC + V_BP);
            else
                y <= 10'd0;
        end
    end

endmodule
