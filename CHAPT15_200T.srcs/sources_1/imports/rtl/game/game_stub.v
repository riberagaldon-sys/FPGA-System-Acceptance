`timescale 1ns/1ps

// Chapter-8 reference game slot.
//
// Every team replaces the internals of one instance while keeping this port
// contract unchanged.  The current implementation is deliberately simple but
// fully interactive: OK starts/restarts, the direction events move a 32x32
// player, Pause freezes the slot, and Back requests a return to HOME.
module game_stub #(
    parameter integer SLOT_ID = 0,
    parameter [23:0] BG_COLOR = 24'h203040,
    parameter [23:0] FG_COLOR = 24'hFFFFFF
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_enable,
    input  wire        event_up,
    input  wire        event_down,
    input  wire        event_left,
    input  wire        event_right,
    input  wire        event_ok,
    input  wire        event_back,
    input  wire        event_pause,
    input  wire        game_tick,
    input  wire        tick_1s,
    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,
    output wire        pixel_on,
    output reg  [23:0] pixel_rgb,
    output wire [15:0] score,
    output wire [3:0]  game_state,
    output wire        exit_request
);

    localparam [3:0]
        ST_READY  = 4'd0,
        ST_RUN    = 4'd1,
        ST_PAUSED = 4'd2;

    localparam integer PLAYER_W = 32;
    localparam integer PLAYER_H = 32;

    reg [10:0] player_x;
    reg [9:0]  player_y;
    reg [10:0] player_x_frame;
    reg [9:0]  player_y_frame;
    reg [15:0] score_live;
    reg [3:0]  game_state_live;
    reg [15:0] score_frame;
    reg [3:0]  state_frame;
    reg        pending_up;
    reg        pending_down;
    reg        pending_left;
    reg        pending_right;
    reg [7:0]  seconds_alive;

    wire status_bar = pixel_y < 10'd64;
    wire player_hit =
        (pixel_x >= player_x_frame) &&
        (pixel_x < player_x_frame + PLAYER_W) &&
        (pixel_y >= player_y_frame) &&
        (pixel_y < player_y_frame + PLAYER_H);
    wire score_bar =
        (pixel_y >= 10'd22) && (pixel_y < 10'd42) &&
        (pixel_x >= 11'd100) &&
        (pixel_x < 11'd100 + ({5'd0, score_frame[5:0]} << 3));
    wire slot_marks =
        (pixel_y >= 10'd14) && (pixel_y < 10'd50) &&
        (pixel_x >= 11'd20) &&
        (pixel_x < 11'd36 + SLOT_ID * 11'd12);

    assign pixel_on = 1'b1;
    assign exit_request = game_enable && event_back;
    assign score = score_frame;
    assign game_state = state_frame;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x     <= 11'd496;
            player_y     <= 10'd284;
            player_x_frame <= 11'd496;
            player_y_frame <= 10'd284;
            score_frame    <= 16'd0;
            state_frame    <= ST_READY;
            score_live   <= 16'd0;
            seconds_alive<= 8'd0;
            game_state_live <= ST_READY;
            pending_up   <= 1'b0;
            pending_down <= 1'b0;
            pending_left <= 1'b0;
            pending_right<= 1'b0;
        end else if (!game_enable) begin
            pending_up    <= 1'b0;
            pending_down  <= 1'b0;
            pending_left  <= 1'b0;
            pending_right <= 1'b0;
        end else begin
            // The standard Chapter-8 port list intentionally contains no
            // frame_start input.  In this reference slot, x=y=0 during the
            // last blanking interval is used as the local frame snapshot
            // point.  The system-level multi-bit state uses the explicit
            // frame_start from lcd_timing_1024x600_frame.
            if ((pixel_x == 11'd0) && (pixel_y == 10'd0)) begin
                player_x_frame <= player_x;
                player_y_frame <= player_y;
                score_frame    <= score_live;
                state_frame    <= game_state_live;
            end

            if (event_up)    pending_up    <= 1'b1;
            if (event_down)  pending_down  <= 1'b1;
            if (event_left)  pending_left  <= 1'b1;
            if (event_right) pending_right <= 1'b1;

            case (game_state_live)
                ST_READY: begin
                    if (event_ok) begin
                        game_state_live <= ST_RUN;
                        player_x      <= 11'd496;
                        player_y      <= 10'd284;
                        score_live    <= 16'd0;
                        seconds_alive <= 8'd0;
                    end
                end

                ST_RUN: begin
                    if (event_pause) begin
                        game_state_live <= ST_PAUSED;
                    end else begin
                        if (tick_1s) begin
                            seconds_alive <= seconds_alive + 8'd1;
                            score_live <= score_live + 16'd1;
                        end

                        if (game_tick) begin
                            if (pending_left && player_x >= 11'd8)
                                player_x <= player_x - 11'd8;
                            else if (pending_right && player_x <= 11'd984)
                                player_x <= player_x + 11'd8;

                            if (pending_up && player_y >= 10'd72)
                                player_y <= player_y - 10'd8;
                            else if (pending_down && player_y <= 10'd560)
                                player_y <= player_y + 10'd8;

                            pending_up    <= 1'b0;
                            pending_down  <= 1'b0;
                            pending_left  <= 1'b0;
                            pending_right <= 1'b0;
                        end
                    end
                end

                ST_PAUSED: begin
                    if (event_pause || event_ok)
                        game_state_live <= ST_RUN;
                end

                default: game_state_live <= ST_READY;
            endcase
        end
    end

    always @(*) begin
        pixel_rgb = BG_COLOR;

        if (status_bar)
            pixel_rgb = 24'h101820;

        if (slot_marks)
            pixel_rgb = FG_COLOR;

        if (score_bar)
            pixel_rgb = 24'hE3B341;

        if (player_hit)
            pixel_rgb = FG_COLOR;

        if (state_frame == ST_READY &&
            pixel_x >= 11'd360 && pixel_x < 11'd664 &&
            pixel_y >= 10'd248 && pixel_y < 10'd352)
            pixel_rgb = 24'hE3B341;

        if (state_frame == ST_PAUSED &&
            pixel_x >= 11'd400 && pixel_x < 11'd624 &&
            pixel_y >= 10'd260 && pixel_y < 10'd340)
            pixel_rgb = 24'hE3B341;
    end

endmodule
