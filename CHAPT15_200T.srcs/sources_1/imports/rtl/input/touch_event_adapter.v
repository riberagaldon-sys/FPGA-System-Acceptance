`timescale 1ns/1ps

module touch_event_adapter #(
    parameter integer CLICK_THR = 30,
    parameter integer SWIPE_THR = 80
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        touch_valid_raw,
    input  wire [15:0] touch_x_raw,
    input  wire [15:0] touch_y_raw,
    input  wire [6:0]  touch_state,

    output reg  [10:0] pointer_x,
    output reg  [9:0]  pointer_y,
    output reg         pointer_down,
    output reg         pointer_click,

    output reg         swipe_up,
    output reg         swipe_down,
    output reg         swipe_left,
    output reg         swipe_right,

    output wire        coord_update_pulse
);

    localparam [6:0] ST_CHECK_TOUCH  = 7'b001_0000;
    localparam [6:0] ST_COORD_HANDLE = 7'b100_0000;

    reg [6:0] touch_state_d;

    (* ASYNC_REG = "TRUE" *) reg [1:0] valid_sync;
    reg valid_d;

    reg [10:0] start_x;
    reg [9:0]  start_y;
    reg [10:0] last_x;
    reg [9:0]  last_y;
    reg        gesture_active;

    wire signed [12:0] dx_release =
        $signed({1'b0,last_x}) - $signed({1'b0,start_x});
    wire signed [11:0] dy_release =
        $signed({1'b0,last_y}) - $signed({1'b0,start_y});

    wire [12:0] abs_dx =
        dx_release[12] ? (~dx_release + 13'd1) : dx_release;
    wire [11:0] abs_dy =
        dy_release[11] ? (~dy_release + 12'd1) : dy_release;

    assign coord_update_pulse =
        (touch_state_d == ST_COORD_HANDLE) &&
        (touch_state   == ST_CHECK_TOUCH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_sync <= 2'b00;
            valid_d    <= 1'b0;
            touch_state_d <= 7'b000_0001;

            pointer_x <= 11'd0;
            pointer_y <= 10'd0;
            pointer_down <= 1'b0;
            pointer_click <= 1'b0;

            swipe_up <= 1'b0;
            swipe_down <= 1'b0;
            swipe_left <= 1'b0;
            swipe_right <= 1'b0;

            start_x <= 11'd0;
            start_y <= 10'd0;
            last_x <= 11'd0;
            last_y <= 10'd0;
            gesture_active <= 1'b0;
        end else begin
            valid_sync <= {valid_sync[0], touch_valid_raw};
            valid_d <= valid_sync[1];
            touch_state_d <= touch_state;

            pointer_click <= 1'b0;
            swipe_up <= 1'b0;
            swipe_down <= 1'b0;
            swipe_left <= 1'b0;
            swipe_right <= 1'b0;

            // A completed coordinate is safe to consume only after
            // st_coord_handle has returned to st_check_touch.
            if (coord_update_pulse) begin
                pointer_x <= touch_x_raw[10:0];
                pointer_y <= touch_y_raw[9:0];
                last_x    <= touch_x_raw[10:0];
                last_y    <= touch_y_raw[9:0];
                pointer_down <= 1'b1;

                if (!gesture_active) begin
                    start_x <= touch_x_raw[10:0];
                    start_y <= touch_y_raw[9:0];
                    gesture_active <= 1'b1;
                end
            end

            // Release is indicated by the debounced/synchronized valid
            // signal falling.  Classify the gesture using the last
            // COMPLETED coordinate.
            if (valid_d && !valid_sync[1]) begin
                pointer_down <= 1'b0;

                if (gesture_active) begin
                    if ((abs_dx < CLICK_THR) && (abs_dy < CLICK_THR)) begin
                        pointer_click <= 1'b1;
                    end else if (abs_dx >= abs_dy) begin
                        if (abs_dx >= SWIPE_THR) begin
                            if (dx_release[12])
                                swipe_left <= 1'b1;
                            else
                                swipe_right <= 1'b1;
                        end
                    end else begin
                        if (abs_dy >= SWIPE_THR) begin
                            if (dy_release[11])
                                swipe_up <= 1'b1;
                            else
                                swipe_down <= 1'b1;
                        end
                    end
                end

                gesture_active <= 1'b0;
            end
        end
    end

endmodule
