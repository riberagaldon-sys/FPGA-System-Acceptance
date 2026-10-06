`timescale 1ns/1ps

// Atomic display-state snapshot.  All bits are captured together at the
// beginning of a frame so the renderer cannot see a half-old/half-new state.
module frame_snapshot_bus #(
    parameter integer WIDTH = 1
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             frame_start,
    input  wire [WIDTH-1:0] live_bus,
    output reg  [WIDTH-1:0] frame_bus
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            frame_bus <= {WIDTH{1'b0}};
        else if (frame_start)
            frame_bus <= live_bus;
    end

endmodule
