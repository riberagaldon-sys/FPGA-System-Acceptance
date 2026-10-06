`timescale 1ns/1ps

module keypad4x4_scan #(
    parameter integer CLK_HZ           = 50_000_000,
    parameter integer ROW_SCAN_HZ      = 1000,
    parameter integer DEBOUNCE_FRAMES  = 3
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] col_i,
    output reg  [3:0] row_o,
    output reg        key_valid,
    output reg  [3:0] key_code
);

    localparam integer ROW_TICKS_CALC = CLK_HZ / ROW_SCAN_HZ;
    localparam integer ROW_TICKS =
        (ROW_TICKS_CALC < 1) ? 1 : ROW_TICKS_CALC;

    reg [31:0] row_tick_count;
    reg [1:0]  row_index;

    (* ASYNC_REG = "TRUE" *) reg [3:0] col_sync0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] col_sync1;

    reg        frame_seen;
    reg        frame_invalid;
    reg [3:0]  frame_code;

    reg        candidate_valid;
    reg [3:0]  candidate_code;
    reg [7:0]  stable_frames;
    reg        press_latched;

    wire [3:0] pressed_col;
    assign pressed_col = ~col_sync1;

    reg       current_valid;
    reg       current_multi;
    reg [1:0] current_col;

    wire [3:0] current_code;
    wire       frame_seen_next;
    wire       frame_invalid_next;
    wire [3:0] frame_code_next;

    // Keep the row/column code identical to the Chapter-4 implementation
    // already verified on the GX-BIDT board.  The physical-label conversion
    // is performed once in input_event_router.
    assign current_code       = {row_index, current_col};
    assign frame_seen_next    = frame_seen | current_valid;
    assign frame_invalid_next =
        frame_invalid | current_multi | (frame_seen & current_valid);
    assign frame_code_next    = current_valid ? current_code : frame_code;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_sync0 <= 4'b1111;
            col_sync1 <= 4'b1111;
        end else begin
            col_sync0 <= col_i;
            col_sync1 <= col_sync0;
        end
    end

    always @(*) begin
        row_o = 4'b1111;

        case (row_index)
            2'd0: row_o = 4'b1110;
            2'd1: row_o = 4'b1101;
            2'd2: row_o = 4'b1011;
            2'd3: row_o = 4'b0111;
            default: row_o = 4'b1111;
        endcase
    end

    always @(*) begin
        current_valid = 1'b0;
        current_multi = 1'b0;
        current_col   = 2'd0;

        case (pressed_col)
            4'b0000: begin
                current_valid = 1'b0;
            end
            4'b0001: begin
                current_valid = 1'b1;
                current_col   = 2'd0;
            end
            4'b0010: begin
                current_valid = 1'b1;
                current_col   = 2'd1;
            end
            4'b0100: begin
                current_valid = 1'b1;
                current_col   = 2'd2;
            end
            4'b1000: begin
                current_valid = 1'b1;
                current_col   = 2'd3;
            end
            default: begin
                current_multi = 1'b1;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_tick_count <= 32'd0;
            row_index      <= 2'd0;
            key_valid      <= 1'b0;
            key_code       <= 4'd0;

            frame_seen     <= 1'b0;
            frame_invalid  <= 1'b0;
            frame_code     <= 4'd0;

            candidate_valid<= 1'b0;
            candidate_code <= 4'd0;
            stable_frames  <= 8'd0;
            press_latched  <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            if (row_tick_count == ROW_TICKS - 1) begin
                row_tick_count <= 32'd0;

                if (row_index == 2'd3) begin
                    row_index     <= 2'd0;
                    frame_seen    <= 1'b0;
                    frame_invalid <= 1'b0;
                    frame_code    <= 4'd0;

                    if (!frame_seen_next) begin
                        candidate_valid <= 1'b0;
                        stable_frames   <= 8'd0;
                        press_latched   <= 1'b0;
                    end else if (frame_invalid_next) begin
                        candidate_valid <= 1'b0;
                        stable_frames   <= 8'd0;
                    end else if (!candidate_valid ||
                                 frame_code_next != candidate_code) begin
                        candidate_valid <= 1'b1;
                        candidate_code  <= frame_code_next;
                        stable_frames   <= 8'd1;

                        if ((DEBOUNCE_FRAMES <= 1) && !press_latched) begin
                            key_code      <= frame_code_next;
                            key_valid     <= 1'b1;
                            press_latched <= 1'b1;
                        end
                    end else if (stable_frames < DEBOUNCE_FRAMES) begin
                        stable_frames <= stable_frames + 8'd1;

                        if ((stable_frames == DEBOUNCE_FRAMES - 1) &&
                            !press_latched) begin
                            key_code      <= candidate_code;
                            key_valid     <= 1'b1;
                            press_latched <= 1'b1;
                        end
                    end
                end else begin
                    row_index <= row_index + 2'd1;

                    if (current_multi) begin
                        frame_invalid <= 1'b1;
                    end else if (current_valid) begin
                        if (frame_seen) begin
                            frame_invalid <= 1'b1;
                        end else begin
                            frame_seen <= 1'b1;
                            frame_code <= current_code;
                        end
                    end
                end
            end else begin
                row_tick_count <= row_tick_count + 32'd1;
            end
        end
    end

endmodule
