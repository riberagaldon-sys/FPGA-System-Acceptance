`timescale 1ns/1ps

module ps2_mouse_init #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer POWERUP_MS   = 500,
    parameter integer RESPONSE_MS  = 100,
    parameter integer RETRY_MS     = 200
)(
    input  wire       clk,
    input  wire       rst_n,

    output reg        tx_start,
    output wire [7:0] tx_byte,
    input  wire       tx_busy,
    input  wire       tx_done,
    input  wire       tx_ack_ok,
    input  wire       tx_error,

    input  wire [7:0] rx_byte,
    input  wire       rx_valid,

    output reg        mouse_ready,
    output reg        init_error
);

    localparam integer POWERUP_CYCLES =
        (CLK_HZ / 1000) * POWERUP_MS;
    localparam integer RESPONSE_CYCLES =
        (CLK_HZ / 1000) * RESPONSE_MS;
    localparam integer RETRY_CYCLES =
        (CLK_HZ / 1000) * RETRY_MS;

    localparam [2:0]
        ST_POWERUP       = 3'd0,
        ST_START_F4      = 3'd1,
        ST_WAIT_TX       = 3'd2,
        ST_WAIT_FA       = 3'd3,
        ST_RETRY_DELAY   = 3'd4,
        ST_READY         = 3'd5;

    reg [2:0]  state;
    reg [31:0] wait_count;

    assign tx_byte = 8'hF4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_POWERUP;
            wait_count  <= 32'd0;
            tx_start    <= 1'b0;
            mouse_ready <= 1'b0;
            init_error  <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                ST_POWERUP: begin
                    mouse_ready <= 1'b0;
                    init_error  <= 1'b0;

                    if (wait_count >= POWERUP_CYCLES - 1) begin
                        wait_count <= 32'd0;
                        state      <= ST_START_F4;
                    end else begin
                        wait_count <= wait_count + 32'd1;
                    end
                end

                ST_START_F4: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        state    <= ST_WAIT_TX;
                    end
                end

                ST_WAIT_TX: begin
                    if (tx_error) begin
                        init_error <= 1'b1;
                        wait_count <= 32'd0;
                        state      <= ST_RETRY_DELAY;
                    end else if (tx_done) begin
                        if (tx_ack_ok) begin
                            wait_count <= 32'd0;
                            state      <= ST_WAIT_FA;
                        end else begin
                            init_error <= 1'b1;
                            wait_count <= 32'd0;
                            state      <= ST_RETRY_DELAY;
                        end
                    end
                end

                ST_WAIT_FA: begin
                    if (rx_valid && rx_byte == 8'hFA) begin
                        mouse_ready <= 1'b1;
                        init_error  <= 1'b0;
                        state       <= ST_READY;
                    end else if (wait_count >= RESPONSE_CYCLES - 1) begin
                        init_error <= 1'b1;
                        wait_count <= 32'd0;
                        state      <= ST_RETRY_DELAY;
                    end else begin
                        wait_count <= wait_count + 32'd1;
                    end
                end

                ST_RETRY_DELAY: begin
                    if (wait_count >= RETRY_CYCLES - 1) begin
                        wait_count <= 32'd0;
                        state      <= ST_START_F4;
                    end else begin
                        wait_count <= wait_count + 32'd1;
                    end
                end

                ST_READY: begin
                    mouse_ready <= 1'b1;
                end

                default: state <= ST_POWERUP;
            endcase
        end
    end

endmodule
