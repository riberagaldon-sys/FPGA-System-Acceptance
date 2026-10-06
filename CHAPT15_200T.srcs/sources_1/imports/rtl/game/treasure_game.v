`timescale 1ns/1ps

// Chapter 9: block treasure game.
//
// Tutorial requirements retained:
//   - 56-pixel status bar;
//   - 24x24 player and 20x20 treasure;
//   - direction events and touch dragging;
//   - score +1 and treasure refresh on rectangle collision;
//   - 60-second countdown;
//   - ready, run, pause, hit and game-over states.
//
// The tutorial's 800x480 play field is adapted to the verified 1024x600 LCD.
module treasure_game #(
    parameter integer SCREEN_W  = 1024,
    parameter integer SCREEN_H  = 600,
    parameter integer STATUS_H  = 56,
    parameter integer GAME_TIME = 60
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

    input  wire [10:0] pointer_x,
    input  wire [9:0]  pointer_y,
    input  wire        pointer_down,

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
        ST_PAUSED = 4'd2,
        ST_HIT    = 4'd3,
        ST_OVER   = 4'd4;

    localparam integer PLAYER_W = 24;
    localparam integer PLAYER_H = 24;
    localparam integer TARGET_W = 20;
    localparam integer TARGET_H = 20;
    localparam integer MOVE_STEP = 8;

    localparam [10:0] PLAYER_X_INIT = 11'd500;
    localparam [9:0]  PLAYER_Y_INIT = 10'd288;
    localparam [10:0] TARGET_X_INIT = 11'd760;
    localparam [9:0]  TARGET_Y_INIT = 10'd320;

    localparam [23:0]
        C_FIELD  = 24'h174D35,
        C_STATUS = 24'h101820,
        C_BORDER = 24'h6BCB9A,
        C_PLAYER = 24'hF4F4F4,
        C_TARGET = 24'hFF5A4F,
        C_GOLD   = 24'hE3B341,
        C_TIME   = 24'h2A9DAD,
        C_OVER   = 24'hA83A3A;

    reg [10:0] player_x;
    reg [9:0]  player_y;
    reg [10:0] target_x;
    reg [9:0]  target_y;
    reg [15:0] score_live;
    reg [6:0]  time_left;
    reg [3:0]  state_live;
    reg [15:0] lfsr;

    reg pending_up;
    reg pending_down;
    reg pending_left;
    reg pending_right;
    reg pointer_down_d;

    // Frame snapshots keep every displayed object stable for a complete frame.
    reg [10:0] player_x_frame;
    reg [9:0]  player_y_frame;
    reg [10:0] target_x_frame;
    reg [9:0]  target_y_frame;
    reg [15:0] score_frame;
    reg [6:0]  time_frame;
    reg [3:0]  state_frame;

    wire collision =
        (player_x < target_x + TARGET_W) &&
        (player_x + PLAYER_W > target_x) &&
        (player_y < target_y + TARGET_H) &&
        (player_y + PLAYER_H > target_y);

    // 10-bit X candidate covers almost the full 1024-pixel width.  Values
    // beyond the legal target origin are wrapped without a divider.
    wire [10:0] next_target_x =
        ({1'b0, lfsr[9:0]} <= SCREEN_W - TARGET_W) ?
        {1'b0, lfsr[9:0]} :
        ({1'b0, lfsr[9:0]} - (SCREEN_W - TARGET_W + 1));

    // 9-bit Y candidate plus the 56-pixel status bar stays inside 600 lines.
    wire [9:0] next_target_y = STATUS_H + {1'b0, lfsr[15:7]};

    assign pixel_on    = 1'b1;
    assign score       = score_frame;
    assign game_state  = state_frame;
    assign exit_request = game_enable && event_back;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x       <= PLAYER_X_INIT;
            player_y       <= PLAYER_Y_INIT;
            target_x       <= TARGET_X_INIT;
            target_y       <= TARGET_Y_INIT;
            score_live     <= 16'd0;
            time_left      <= GAME_TIME;
            state_live     <= ST_READY;
            lfsr           <= 16'h1ACE;
            pending_up     <= 1'b0;
            pending_down   <= 1'b0;
            pending_left   <= 1'b0;
            pending_right  <= 1'b0;
            pointer_down_d <= 1'b0;
            player_x_frame <= PLAYER_X_INIT;
            player_y_frame <= PLAYER_Y_INIT;
            target_x_frame <= TARGET_X_INIT;
            target_y_frame <= TARGET_Y_INIT;
            score_frame    <= 16'd0;
            time_frame     <= GAME_TIME;
            state_frame    <= ST_READY;
        end else begin
            // x^16 + x^14 + x^13 + x^11 + 1
            lfsr <= {lfsr[14:0],
                     lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            pointer_down_d <= pointer_down;

            // The timing generator presents x=y=0 once per frame.  Capture
            // all display-visible state together at that point.
            if ((pixel_x == 11'd0) && (pixel_y == 10'd0)) begin
                player_x_frame <= player_x;
                player_y_frame <= player_y;
                target_x_frame <= target_x;
                target_y_frame <= target_y;
                score_frame    <= score_live;
                time_frame     <= time_left;
                state_frame    <= state_live;
            end

            if (!game_enable) begin
                player_x      <= PLAYER_X_INIT;
                player_y      <= PLAYER_Y_INIT;
                target_x      <= TARGET_X_INIT;
                target_y      <= TARGET_Y_INIT;
                score_live    <= 16'd0;
                time_left     <= GAME_TIME;
                state_live    <= ST_READY;
                pending_up    <= 1'b0;
                pending_down  <= 1'b0;
                pending_left  <= 1'b0;
                pending_right <= 1'b0;
            end else begin
                case (state_live)
                    ST_READY: begin
                        if (event_ok) begin
                            player_x      <= PLAYER_X_INIT;
                            player_y      <= PLAYER_Y_INIT;
                            target_x      <= TARGET_X_INIT;
                            target_y      <= TARGET_Y_INIT;
                            score_live    <= 16'd0;
                            time_left     <= GAME_TIME;
                            state_live    <= ST_RUN;
                            pending_up    <= 1'b0;
                            pending_down  <= 1'b0;
                            pending_left  <= 1'b0;
                            pending_right <= 1'b0;
                        end
                    end

                    ST_RUN: begin
                        if (event_pause) begin
                            state_live <= ST_PAUSED;
                            pending_up    <= 1'b0;
                            pending_down  <= 1'b0;
                            pending_left  <= 1'b0;
                            pending_right <= 1'b0;
                        end else if (collision) begin
                            state_live <= ST_HIT;
                        end else begin
                            if (tick_1s) begin
                                if (time_left > 7'd1)
                                    time_left <= time_left - 7'd1;
                                else begin
                                    time_left <= 7'd0;
                                    state_live <= ST_OVER;
                                end
                            end

                            if (pointer_down) begin
                                if (pointer_x < PLAYER_W/2)
                                    player_x <= 11'd0;
                                else if (pointer_x > SCREEN_W - PLAYER_W/2)
                                    player_x <= SCREEN_W - PLAYER_W;
                                else
                                    player_x <= pointer_x - PLAYER_W/2;

                                if (pointer_y < STATUS_H + PLAYER_H/2)
                                    player_y <= STATUS_H;
                                else if (pointer_y > SCREEN_H - PLAYER_H/2)
                                    player_y <= SCREEN_H - PLAYER_H;
                                else
                                    player_y <= pointer_y - PLAYER_H/2;
                                pending_up    <= 1'b0;
                                pending_down  <= 1'b0;
                                pending_left  <= 1'b0;
                                pending_right <= 1'b0;
                            end else if (pointer_down_d) begin
                                // The touch adapter emits a swipe event on the
                                // release cycle.  The player has already been
                                // dragged to the requested coordinate, so
                                // discard that release gesture here to avoid
                                // an extra one-step move.
                                pending_up    <= 1'b0;
                                pending_down  <= 1'b0;
                                pending_left  <= 1'b0;
                                pending_right <= 1'b0;
                            end else if (game_tick) begin
                                if (pending_left || event_left) begin
                                    if (player_x >= MOVE_STEP)
                                        player_x <= player_x - MOVE_STEP;
                                    else
                                        player_x <= 11'd0;
                                end else if (pending_right || event_right) begin
                                    if (player_x <= SCREEN_W - PLAYER_W - MOVE_STEP)
                                        player_x <= player_x + MOVE_STEP;
                                    else
                                        player_x <= SCREEN_W - PLAYER_W;
                                end

                                if (pending_up || event_up) begin
                                    if (player_y >= STATUS_H + MOVE_STEP)
                                        player_y <= player_y - MOVE_STEP;
                                    else
                                        player_y <= STATUS_H;
                                end else if (pending_down || event_down) begin
                                    if (player_y <= SCREEN_H - PLAYER_H - MOVE_STEP)
                                        player_y <= player_y + MOVE_STEP;
                                    else
                                        player_y <= SCREEN_H - PLAYER_H;
                                end

                                pending_up    <= 1'b0;
                                pending_down  <= 1'b0;
                                pending_left  <= 1'b0;
                                pending_right <= 1'b0;
                            end else begin
                                if (event_up)
                                    pending_up <= 1'b1;
                                if (event_down)
                                    pending_down <= 1'b1;
                                if (event_left)
                                    pending_left <= 1'b1;
                                if (event_right)
                                    pending_right <= 1'b1;
                            end
                        end
                    end

                    ST_HIT: begin
                        score_live <= score_live + 16'd1;
                        target_x   <= next_target_x;
                        target_y   <= next_target_y;
                        state_live <= ST_RUN;
                    end

                    ST_PAUSED: begin
                        if (event_pause || event_ok)
                            state_live <= ST_RUN;
                    end

                    ST_OVER: begin
                        if (event_ok) begin
                            player_x      <= PLAYER_X_INIT;
                            player_y      <= PLAYER_Y_INIT;
                            target_x      <= next_target_x;
                            target_y      <= next_target_y;
                            score_live    <= 16'd0;
                            time_left     <= GAME_TIME;
                            state_live    <= ST_RUN;
                            pending_up    <= 1'b0;
                            pending_down  <= 1'b0;
                            pending_left  <= 1'b0;
                            pending_right <= 1'b0;
                        end
                    end

                    default: state_live <= ST_READY;
                endcase
            end
        end
    end

    wire status_pixel = pixel_y < STATUS_H;
    wire border_pixel = (pixel_y == STATUS_H) ||
                        (pixel_x == 11'd0) || (pixel_x == SCREEN_W-1) ||
                        (pixel_y == SCREEN_H-1);
    wire player_pixel =
        (pixel_x >= player_x_frame) &&
        (pixel_x < player_x_frame + PLAYER_W) &&
        (pixel_y >= player_y_frame) &&
        (pixel_y < player_y_frame + PLAYER_H);
    wire target_pixel =
        (pixel_x >= target_x_frame) &&
        (pixel_x < target_x_frame + TARGET_W) &&
        (pixel_y >= target_y_frame) &&
        (pixel_y < target_y_frame + TARGET_H);

    wire [10:0] score_width = {score_frame[5:0], 4'b0000};
    wire [10:0] time_width =
        {1'b0, time_frame, 3'b000} + {3'b000, time_frame, 1'b0};
    wire score_bar =
        (pixel_y >= 10'd12) && (pixel_y < 10'd24) &&
        (pixel_x >= 11'd160) && (pixel_x < 11'd160 + score_width);
    wire time_bar =
        (pixel_y >= 10'd34) && (pixel_y < 10'd46) &&
        (pixel_x >= 11'd160) && (pixel_x < 11'd160 + time_width);
    wire chapter_mark =
        (pixel_x >= 11'd20) && (pixel_x < 11'd116) &&
        (pixel_y >= 10'd12) && (pixel_y < 10'd46);

    wire ready_box =
        (pixel_x >= 11'd360) && (pixel_x < 11'd664) &&
        (pixel_y >= 10'd248) && (pixel_y < 10'd352);
    wire pause_box =
        (pixel_x >= 11'd400) && (pixel_x < 11'd624) &&
        (pixel_y >= 10'd260) && (pixel_y < 10'd340);
    wire over_box =
        (pixel_x >= 11'd352) && (pixel_x < 11'd672) &&
        (pixel_y >= 10'd244) && (pixel_y < 10'd356);

    always @(*) begin
        pixel_rgb = C_FIELD;

        if (status_pixel)
            pixel_rgb = C_STATUS;
        if (border_pixel)
            pixel_rgb = C_BORDER;
        if (chapter_mark)
            pixel_rgb = C_GOLD;
        if (score_bar)
            pixel_rgb = C_GOLD;
        if (time_bar)
            pixel_rgb = C_TIME;

        if ((state_frame == ST_RUN || state_frame == ST_PAUSED ||
             state_frame == ST_HIT) && target_pixel)
            pixel_rgb = C_TARGET;
        if ((state_frame == ST_RUN || state_frame == ST_PAUSED ||
             state_frame == ST_HIT) && player_pixel)
            pixel_rgb = C_PLAYER;

        if ((state_frame == ST_READY) && ready_box)
            pixel_rgb = C_GOLD;
        if ((state_frame == ST_PAUSED) && pause_box)
            pixel_rgb = C_GOLD;
        if ((state_frame == ST_OVER) && over_box)
            pixel_rgb = C_OVER;
    end

endmodule
