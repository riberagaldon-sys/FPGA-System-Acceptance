`timescale 1ns/1ps

// Transfers a single-cycle pulse between unrelated clock domains by toggling
// a bit in the source domain and detecting the synchronized change.
module pulse_sync_toggle(
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire src_pulse,
    input  wire dst_clk,
    input  wire dst_rst_n,
    output reg  dst_pulse
);

    reg src_toggle;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dst_sync;
    reg dst_seen;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            src_toggle <= 1'b0;
        else if (src_pulse)
            src_toggle <= ~src_toggle;
    end

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_sync  <= 2'b00;
            dst_seen  <= 1'b0;
            dst_pulse <= 1'b0;
        end else begin
            dst_sync  <= {dst_sync[0], src_toggle};
            dst_pulse <= dst_sync[1] ^ dst_seen;
            dst_seen  <= dst_sync[1];
        end
    end

endmodule
