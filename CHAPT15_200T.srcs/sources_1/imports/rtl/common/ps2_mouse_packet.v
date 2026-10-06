`timescale 1ns/1ps

module ps2_mouse_packet #(
    parameter integer X_MAX = 1023,
    parameter integer Y_MAX = 599,
    parameter integer X_INIT = 512,
    parameter integer Y_INIT = 300,
    parameter integer MAX_DELTA = 64
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [7:0] data_byte,
    input  wire       data_valid,
    input  wire       frame_error,

    output reg        packet_valid,
    output reg  [2:0] buttons,
    output reg signed [8:0] dx,
    output reg signed [8:0] dy,
    output reg [10:0] mouse_x,
    output reg [9:0]  mouse_y
);

    reg [1:0] byte_index;
    reg [7:0] packet0;
    reg [7:0] packet1;

    wire signed [8:0] dx_value;
    wire signed [8:0] dy_value;
    wire signed [11:0] x_candidate;
    wire signed [11:0] y_candidate;
    wire               dx_in_range;
    wire               dy_in_range;
    wire               packet_plausible;

    // A legal first byte always has bit 3 set.  Reject overflow packets,
    // sign-inconsistent packets and unusually large single-report motion.
    // The last check prevents a rare misaligned byte from becoming a sudden
    // upward cursor step while a paint stroke is active.
    assign dx_in_range =
        (dx_value >= -MAX_DELTA) && (dx_value <= MAX_DELTA);
    assign dy_in_range =
        (dy_value >= -MAX_DELTA) && (dy_value <= MAX_DELTA);

    assign packet_plausible =
        packet0[3] && !packet0[6] && !packet0[7] &&
        (packet0[4] == packet1[7]) &&
        (packet0[5] == data_byte[7]) &&
        dx_in_range && dy_in_range;

    assign dx_value = {packet0[4], packet1};
    assign dy_value = {packet0[5], data_byte};

    assign x_candidate =
        $signed({1'b0, mouse_x}) +
        $signed({{3{dx_value[8]}}, dx_value});

    assign y_candidate =
        $signed({2'b00, mouse_y}) -
        $signed({{3{dy_value[8]}}, dy_value});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_index   <= 2'd0;
            packet0      <= 8'd0;
            packet1      <= 8'd0;
            packet_valid <= 1'b0;
            buttons      <= 3'b000;
            dx           <= 9'sd0;
            dy           <= 9'sd0;
            mouse_x      <= X_INIT;
            mouse_y      <= Y_INIT;
        end else begin
            packet_valid <= 1'b0;

            if (!enable) begin
                byte_index <= 2'd0;
                buttons    <= 3'b000;
                dx         <= 9'sd0;
                dy         <= 9'sd0;
            end else if (frame_error) begin
                // Never let the byte following a parity/timeout failure be
                // interpreted as the remainder of the damaged packet.
                byte_index <= 2'd0;
                buttons    <= 3'b000;
                dx         <= 9'sd0;
                dy         <= 9'sd0;
            end else if (data_valid) begin
                case (byte_index)
                    2'd0: begin
                        // Bit 3 is always 1 in the first packet byte.
                        if (data_byte[3]) begin
                            packet0    <= data_byte;
                            byte_index <= 2'd1;
                        end
                    end

                    2'd1: begin
                        packet1    <= data_byte;
                        byte_index <= 2'd2;
                    end

                    2'd2: begin
                        if (packet_plausible) begin
                            byte_index   <= 2'd0;
                            packet_valid <= 1'b1;
                            buttons      <= packet0[2:0];
                            dx           <= dx_value;
                            dy           <= dy_value;

                            if (x_candidate < 0)
                                mouse_x <= 11'd0;
                            else if (x_candidate > X_MAX)
                                mouse_x <= X_MAX;
                            else
                                mouse_x <= x_candidate[10:0];

                            if (y_candidate < 0)
                                mouse_y <= 10'd0;
                            else if (y_candidate > Y_MAX)
                                mouse_y <= Y_MAX;
                            else
                                mouse_y <= y_candidate[9:0];
                        end else begin
                            // Sliding resynchronizer: retain the newest
                            // header-looking byte(s) instead of blindly
                            // accepting the next three bytes as a packet.
                            if (packet1[3]) begin
                                packet0    <= packet1;
                                packet1    <= data_byte;
                                byte_index <= 2'd2;
                            end else if (data_byte[3]) begin
                                packet0    <= data_byte;
                                byte_index <= 2'd1;
                            end else begin
                                byte_index <= 2'd0;
                            end
                        end
                    end

                    default: byte_index <= 2'd0;
                endcase
            end
        end
    end

endmodule
