`timescale 1ns/1ps

module ps2_rx #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer TIMEOUT_US   = 2000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg  [7:0] data_byte,
    output reg        data_valid,
    output reg        frame_error
);

    localparam integer TIMEOUT_CYCLES_CALC =
        (CLK_HZ / 1_000_000) * TIMEOUT_US;
    localparam integer TIMEOUT_CYCLES =
        (TIMEOUT_CYCLES_CALC < 1) ? 1 : TIMEOUT_CYCLES_CALC;

    (* ASYNC_REG = "TRUE" *) reg [2:0] ps2_clk_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ps2_data_sync;

    reg [3:0]  bit_count;
    reg [10:0] frame_bits;
    reg [31:0] timeout_count;

    wire ps2_clk_fall;
    wire sampled_data;
    wire parity_ok;

    assign ps2_clk_fall = ps2_clk_sync[2] && !ps2_clk_sync[1];
    assign sampled_data = ps2_data_sync[1];
    assign parity_ok = ((^frame_bits[8:1]) ^ frame_bits[9]) == 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync  <= 3'b111;
            ps2_data_sync <= 2'b11;
        end else begin
            ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[0], ps2_data};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count     <= 4'd0;
            frame_bits    <= 11'h7FF;
            timeout_count <= 32'd0;
            data_byte     <= 8'd0;
            data_valid    <= 1'b0;
            frame_error   <= 1'b0;
        end else begin
            data_valid  <= 1'b0;
            frame_error <= 1'b0;

            if (bit_count != 4'd0) begin
                if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                    bit_count     <= 4'd0;
                    timeout_count <= 32'd0;
                    frame_error   <= 1'b1;
                end else begin
                    timeout_count <= timeout_count + 32'd1;
                end
            end else begin
                timeout_count <= 32'd0;
            end

            if (ps2_clk_fall) begin
                timeout_count <= 32'd0;

                if (bit_count == 4'd0) begin
                    if (sampled_data == 1'b0) begin
                        frame_bits[0] <= 1'b0;
                        bit_count     <= 4'd1;
                    end
                end else if (bit_count < 4'd10) begin
                    frame_bits[bit_count] <= sampled_data;
                    bit_count             <= bit_count + 4'd1;
                end else begin
                    bit_count <= 4'd0;

                    if ((frame_bits[0] == 1'b0) &&
                        (sampled_data == 1'b1) &&
                        parity_ok) begin
                        data_byte  <= frame_bits[8:1];
                        data_valid <= 1'b1;
                    end else begin
                        frame_error <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
