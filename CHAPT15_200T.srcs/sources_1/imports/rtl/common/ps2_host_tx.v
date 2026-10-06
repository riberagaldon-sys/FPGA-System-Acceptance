`timescale 1ns/1ps

module ps2_host_tx #(
    parameter integer CLK_HZ        = 50_000_000,
    parameter integer INHIBIT_US    = 120,
    parameter integer REQUEST_US    = 10,
    parameter integer TIMEOUT_US    = 20_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_byte,
    input  wire       ps2_clk_in,
    input  wire       ps2_data_in,

    output reg        ps2_clk_drive_low,
    output reg        ps2_data_drive_low,
    output reg        busy,
    output reg        done,
    output reg        ack_ok,
    output reg        tx_error
);

    localparam integer INHIBIT_CYCLES_CALC =
        (CLK_HZ / 1_000_000) * INHIBIT_US;
    localparam integer REQUEST_CYCLES_CALC =
        (CLK_HZ / 1_000_000) * REQUEST_US;
    localparam integer TIMEOUT_CYCLES_CALC =
        (CLK_HZ / 1_000_000) * TIMEOUT_US;

    localparam integer INHIBIT_CYCLES =
        (INHIBIT_CYCLES_CALC < 1) ? 1 : INHIBIT_CYCLES_CALC;
    localparam integer REQUEST_CYCLES =
        (REQUEST_CYCLES_CALC < 1) ? 1 : REQUEST_CYCLES_CALC;
    localparam integer TIMEOUT_CYCLES =
        (TIMEOUT_CYCLES_CALC < 1) ? 1 : TIMEOUT_CYCLES_CALC;

    localparam [2:0]
        ST_IDLE       = 3'd0,
        ST_INHIBIT    = 3'd1,
        ST_REQUEST    = 3'd2,
        ST_SEND       = 3'd3,
        ST_WAIT_ACK   = 3'd4,
        ST_FINISH     = 3'd5,
        ST_ERROR      = 3'd6;

    (* ASYNC_REG = "TRUE" *) reg [2:0] ps2_clk_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ps2_data_sync;

    reg [2:0]  state;
    reg [31:0] phase_count;
    reg [31:0] timeout_count;
    reg [3:0]  frame_phase;
    reg [7:0]  tx_latched;
    reg        parity_bit;

    wire ps2_clk_fall;
    wire ps2_clk_rise;
    wire sampled_data;

    assign ps2_clk_fall = ps2_clk_sync[2] && !ps2_clk_sync[1];
    assign ps2_clk_rise = !ps2_clk_sync[2] && ps2_clk_sync[1];
    assign sampled_data = ps2_data_sync[1];

    function automatic frame_value;
        input [3:0] phase;
        begin
            case (phase)
                4'd0: frame_value = 1'b0; // start
                4'd1: frame_value = tx_latched[0];
                4'd2: frame_value = tx_latched[1];
                4'd3: frame_value = tx_latched[2];
                4'd4: frame_value = tx_latched[3];
                4'd5: frame_value = tx_latched[4];
                4'd6: frame_value = tx_latched[5];
                4'd7: frame_value = tx_latched[6];
                4'd8: frame_value = tx_latched[7];
                4'd9: frame_value = parity_bit;
                default: frame_value = 1'b1; // stop/release
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync  <= 3'b111;
            ps2_data_sync <= 2'b11;
        end else begin
            ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk_in};
            ps2_data_sync <= {ps2_data_sync[0], ps2_data_in};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= ST_IDLE;
            phase_count        <= 32'd0;
            timeout_count      <= 32'd0;
            frame_phase        <= 4'd0;
            tx_latched         <= 8'd0;
            parity_bit         <= 1'b1;

            ps2_clk_drive_low  <= 1'b0;
            ps2_data_drive_low <= 1'b0;
            busy               <= 1'b0;
            done               <= 1'b0;
            ack_ok             <= 1'b0;
            tx_error           <= 1'b0;
        end else begin
            done     <= 1'b0;
            tx_error <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy               <= 1'b0;
                    ack_ok             <= 1'b0;
                    ps2_clk_drive_low  <= 1'b0;
                    ps2_data_drive_low <= 1'b0;
                    phase_count        <= 32'd0;
                    timeout_count      <= 32'd0;

                    if (start && ps2_clk_in && ps2_data_in) begin
                        tx_latched        <= tx_byte;
                        parity_bit        <= ~(^tx_byte);
                        ps2_clk_drive_low <= 1'b1;
                        busy              <= 1'b1;
                        state             <= ST_INHIBIT;
                    end
                end

                ST_INHIBIT: begin
                    if (phase_count >= INHIBIT_CYCLES - 1) begin
                        phase_count        <= 32'd0;
                        ps2_data_drive_low <= 1'b1; // request-to-send
                        state              <= ST_REQUEST;
                    end else begin
                        phase_count <= phase_count + 32'd1;
                    end
                end

                ST_REQUEST: begin
                    if (phase_count >= REQUEST_CYCLES - 1) begin
                        phase_count       <= 32'd0;
                        timeout_count     <= 32'd0;
                        frame_phase       <= 4'd0;
                        ps2_clk_drive_low <= 1'b0; // device now supplies clock
                        state             <= ST_SEND;
                    end else begin
                        phase_count <= phase_count + 32'd1;
                    end
                end

                ST_SEND: begin
                    if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        state <= ST_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 32'd1;

                        if (ps2_clk_fall) begin
                            timeout_count <= 32'd0;

                            if (frame_phase < 4'd10) begin
                                frame_phase <= frame_phase + 4'd1;
                                ps2_data_drive_low <=
                                    ~frame_value(frame_phase + 4'd1);
                            end else begin
                                // Stop bit has been released.  The device
                                // supplies one more clock for the ACK bit.
                                ps2_data_drive_low <= 1'b0;
                                state <= ST_WAIT_ACK;
                            end
                        end
                    end
                end

                ST_WAIT_ACK: begin
                    if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        state <= ST_ERROR;
                    end else begin
                        timeout_count <= timeout_count + 32'd1;

                        if (ps2_clk_rise) begin
                            ack_ok <= (sampled_data == 1'b0);
                            state  <= ST_FINISH;
                        end
                    end
                end

                ST_FINISH: begin
                    ps2_clk_drive_low  <= 1'b0;
                    ps2_data_drive_low <= 1'b0;
                    busy               <= 1'b0;
                    done               <= 1'b1;
                    state              <= ST_IDLE;
                end

                ST_ERROR: begin
                    ps2_clk_drive_low  <= 1'b0;
                    ps2_data_drive_low <= 1'b0;
                    busy               <= 1'b0;
                    ack_ok             <= 1'b0;
                    tx_error           <= 1'b1;
                    state              <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
