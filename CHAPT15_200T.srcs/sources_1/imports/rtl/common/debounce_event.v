`timescale 1ns/1ps

module debounce_event #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer DEBOUNCE_MS  = 20,
    parameter integer ACTIVE_LOW   = 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_level,
    output reg  press_pulse,
    output reg  release_pulse
);

    localparam integer STABLE_CYCLES_CALC =
        (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer STABLE_CYCLES =
        (STABLE_CYCLES_CALC < 1) ? 1 : STABLE_CYCLES_CALC;
    localparam         IDLE_RAW =
        (ACTIVE_LOW != 0) ? 1'b1 : 1'b0;

    (* ASYNC_REG = "TRUE" *) reg sync0;
    (* ASYNC_REG = "TRUE" *) reg sync1;
    reg [31:0] stable_count;

    wire active_sample;
    assign active_sample = (ACTIVE_LOW != 0) ? ~sync1 : sync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= IDLE_RAW;
            sync1 <= IDLE_RAW;
        end else begin
            sync0 <= key_in;
            sync1 <= sync0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_level    <= 1'b0;
            press_pulse  <= 1'b0;
            release_pulse<= 1'b0;
            stable_count <= 32'd0;
        end else begin
            press_pulse   <= 1'b0;
            release_pulse <= 1'b0;

            if (active_sample == key_level) begin
                stable_count <= 32'd0;
            end else if (stable_count >= STABLE_CYCLES - 1) begin
                stable_count <= 32'd0;
                key_level    <= active_sample;

                if (active_sample)
                    press_pulse <= 1'b1;
                else
                    release_pulse <= 1'b1;
            end else begin
                stable_count <= stable_count + 32'd1;
            end
        end
    end

endmodule
