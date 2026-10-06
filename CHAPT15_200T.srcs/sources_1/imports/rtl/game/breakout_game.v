`timescale 1ns/1ps

// Chapter 12: 10 x 5 brick-breaker game for the verified 1024 x 600 LCD.
//
// The object sizes follow the tutorial: 14 x 14 ball, 112 x 16 paddle,
// 68 x 20 bricks with a four-pixel horizontal gap.  The original 800-pixel
// playfield is centred in the 1024-pixel panel.
module breakout_game(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_enable,

    input  wire        event_left,
    input  wire        event_right,
    input  wire        event_ok,
    input  wire        event_back,
    input  wire        event_pause,
    input  wire        game_tick,

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

    localparam integer FIELD_LEFT   = 112;
    localparam integer FIELD_RIGHT  = 912;
    localparam integer FIELD_TOP    = 64;
    localparam integer FIELD_BOTTOM = 590;

    localparam integer BALL_SIZE = 14;
    localparam integer PADDLE_W   = 112;
    localparam integer PADDLE_H   = 16;
    localparam integer PADDLE_Y   = 536;
    localparam integer PADDLE_STEP= 16;

    localparam integer BRICK_COLS  = 10;
    localparam integer BRICK_ROWS  = 5;
    localparam integer BRICK_W     = 68;
    localparam integer BRICK_H     = 20;
    localparam integer BRICK_PITCH_X = 72;
    localparam integer BRICK_PITCH_Y = 24;
    localparam integer BRICK_X0    = 162;
    localparam integer BRICK_Y0    = 96;

    localparam integer PADDLE_X_INIT = 456;
    localparam integer BALL_X_OFFSET  = 49;
    localparam integer BALL_Y_READY   = PADDLE_Y - BALL_SIZE;

    localparam [3:0]
        ST_READY     = 4'd0,
        ST_RUN       = 4'd1,
        ST_PAUSED    = 4'd2,
        ST_LIFE_LOST = 4'd3,
        ST_WIN       = 4'd4,
        ST_OVER      = 4'd5;

    localparam [23:0]
        C_OUTSIDE = 24'h101820,
        C_STATUS  = 24'h17212B,
        C_FIELD   = 24'h351A20,
        C_BORDER  = 24'hC45A5A,
        C_PADDLE  = 24'hF4F4F4,
        C_BALL    = 24'hFFE16A,
        C_YELLOW  = 24'hE3B341,
        C_GREEN   = 24'h62D394,
        C_RED     = 24'hE05252,
        C_ORANGE  = 24'hE8874A,
        C_PURPLE  = 24'h8E62C6,
        C_CYAN    = 24'h2A9DAD;

    reg [10:0] ball_x_live;
    reg [9:0]  ball_y_live;
    reg signed [5:0] vx_live;
    reg signed [5:0] vy_live;
    reg [10:0] paddle_x_live;
    reg [49:0] brick_alive_live;
    reg [5:0]  bricks_remaining_live;
    reg [2:0]  lives_live;
    reg [15:0] score_live;
    reg [3:0]  state_live;

    // Pipeline the brick lookup.  The original implementation calculated
    // the next ball position, divided it into a 10 x 5 grid, dynamically
    // selected one of 50 brick bits and updated the score in one 51.2 MHz
    // clock period.  Registering the candidate brick address removes that
    // 63-level combinational path without changing the 60 Hz game behavior.
    reg        brick_check_pending;
    reg [5:0]  brick_check_index;

    // LCD-frame snapshots avoid changing object positions halfway through a
    // raster scan.
    reg [10:0] ball_x_frame;
    reg [9:0]  ball_y_frame;
    reg [10:0] paddle_x_frame;
    reg [49:0] brick_alive_frame;
    reg [2:0]  lives_frame;
    reg [15:0] score_frame;
    reg [3:0]  state_frame;

    integer calc_x;
    integer calc_y;
    integer calc_vx;
    integer calc_vy;
    integer calc_center_x;
    integer calc_center_y;
    integer calc_brick_col;
    integer calc_brick_row;
    integer calc_brick_index;

    assign pixel_on     = 1'b1;
    assign score        = score_frame;
    assign game_state   = state_frame;
    assign exit_request = game_enable && event_back;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ball_x_live          <= PADDLE_X_INIT + BALL_X_OFFSET;
            ball_y_live          <= BALL_Y_READY;
            vx_live              <= 6'sd4;
            vy_live              <= -6'sd4;
            paddle_x_live        <= PADDLE_X_INIT;
            brick_alive_live     <= {50{1'b1}};
            bricks_remaining_live<= 6'd50;
            lives_live           <= 3'd3;
            score_live           <= 16'd0;
            state_live           <= ST_READY;
            brick_check_pending  <= 1'b0;
            brick_check_index    <= 6'd0;

            ball_x_frame         <= PADDLE_X_INIT + BALL_X_OFFSET;
            ball_y_frame         <= BALL_Y_READY;
            paddle_x_frame       <= PADDLE_X_INIT;
            brick_alive_frame    <= {50{1'b1}};
            lives_frame          <= 3'd3;
            score_frame          <= 16'd0;
            state_frame          <= ST_READY;
        end else begin
            if ((pixel_x == 11'd0) && (pixel_y == 10'd0)) begin
                ball_x_frame      <= ball_x_live;
                ball_y_frame      <= ball_y_live;
                paddle_x_frame    <= paddle_x_live;
                brick_alive_frame <= brick_alive_live;
                lives_frame       <= lives_live;
                score_frame       <= score_live;
                state_frame       <= state_live;
            end

            if (!game_enable) begin
                ball_x_live           <= PADDLE_X_INIT + BALL_X_OFFSET;
                ball_y_live           <= BALL_Y_READY;
                vx_live               <= 6'sd4;
                vy_live               <= -6'sd4;
                paddle_x_live         <= PADDLE_X_INIT;
                brick_alive_live      <= {50{1'b1}};
                bricks_remaining_live <= 6'd50;
                lives_live            <= 3'd3;
                score_live            <= 16'd0;
                state_live            <= ST_READY;
                brick_check_pending   <= 1'b0;
                brick_check_index     <= 6'd0;
            end else begin
                case (state_live)
                    ST_READY: begin
                        // The ball remains attached to the paddle before
                        // launch.  Keyboard/five-way/matrix and touch can all
                        // position the paddle.
                        ball_x_live <= paddle_x_live + BALL_X_OFFSET;
                        ball_y_live <= BALL_Y_READY;
                        vx_live     <= 6'sd4;
                        vy_live     <= -6'sd4;

                        if (pointer_down) begin
                            if (pointer_x <= FIELD_LEFT + PADDLE_W/2)
                                paddle_x_live <= FIELD_LEFT;
                            else if (pointer_x >= FIELD_RIGHT - PADDLE_W/2)
                                paddle_x_live <= FIELD_RIGHT - PADDLE_W;
                            else
                                paddle_x_live <= pointer_x - PADDLE_W/2;
                        end else if (event_left) begin
                            if (paddle_x_live <= FIELD_LEFT + PADDLE_STEP)
                                paddle_x_live <= FIELD_LEFT;
                            else
                                paddle_x_live <= paddle_x_live - PADDLE_STEP;
                        end else if (event_right) begin
                            if (paddle_x_live >= FIELD_RIGHT-PADDLE_W-PADDLE_STEP)
                                paddle_x_live <= FIELD_RIGHT - PADDLE_W;
                            else
                                paddle_x_live <= paddle_x_live + PADDLE_STEP;
                        end

                        if (event_ok)
                            state_live <= ST_RUN;
                    end

                    ST_RUN: begin
                        if (event_pause) begin
                            state_live <= ST_PAUSED;
                        end else begin
                            if (pointer_down) begin
                                if (pointer_x <= FIELD_LEFT + PADDLE_W/2)
                                    paddle_x_live <= FIELD_LEFT;
                                else if (pointer_x >= FIELD_RIGHT-PADDLE_W/2)
                                    paddle_x_live <= FIELD_RIGHT - PADDLE_W;
                                else
                                    paddle_x_live <= pointer_x - PADDLE_W/2;
                            end else if (event_left) begin
                                if (paddle_x_live <= FIELD_LEFT + PADDLE_STEP)
                                    paddle_x_live <= FIELD_LEFT;
                                else
                                    paddle_x_live <= paddle_x_live-PADDLE_STEP;
                            end else if (event_right) begin
                                if (paddle_x_live >= FIELD_RIGHT-PADDLE_W-PADDLE_STEP)
                                    paddle_x_live <= FIELD_RIGHT - PADDLE_W;
                                else
                                    paddle_x_live <= paddle_x_live+PADDLE_STEP;
                            end

                            if (game_tick) begin
                                // A new 60 Hz update starts a fresh brick
                                // candidate lookup.  Any valid candidate is
                                // consumed on the following 51.2 MHz clock.
                                brick_check_pending <= 1'b0;

                                calc_x  = $signed({1'b0,ball_x_live}) + vx_live;
                                calc_y  = $signed({1'b0,ball_y_live}) + vy_live;
                                calc_vx = vx_live;
                                calc_vy = vy_live;

                                if (calc_x <= FIELD_LEFT) begin
                                    calc_x  = FIELD_LEFT;
                                    calc_vx = (calc_vx < 0) ? -calc_vx : calc_vx;
                                end else if (calc_x >= FIELD_RIGHT-BALL_SIZE) begin
                                    calc_x  = FIELD_RIGHT-BALL_SIZE;
                                    calc_vx = (calc_vx > 0) ? -calc_vx : calc_vx;
                                end

                                if (calc_y <= FIELD_TOP) begin
                                    calc_y  = FIELD_TOP;
                                    calc_vy = (calc_vy < 0) ? -calc_vy : calc_vy;
                                end

                                // Downward crossing of the paddle top.
                                if ((calc_vy > 0) &&
                                    (ball_y_live + BALL_SIZE <= PADDLE_Y+4) &&
                                    (calc_y + BALL_SIZE >= PADDLE_Y) &&
                                    (calc_x + BALL_SIZE > paddle_x_live) &&
                                    (calc_x < paddle_x_live + PADDLE_W)) begin
                                    calc_y  = PADDLE_Y - BALL_SIZE;
                                    calc_vy = -((calc_vy < 0) ? -calc_vy : calc_vy);

                                    if (calc_x + BALL_SIZE/2 < paddle_x_live+PADDLE_W/3)
                                        calc_vx = -6;
                                    else if (calc_x + BALL_SIZE/2 >
                                             paddle_x_live+(PADDLE_W*2)/3)
                                        calc_vx = 6;
                                end

                                // Centre-point mapping into the 10 x 5 brick
                                // grid.  Explicit thresholds replace the
                                // variable-width division hardware that made
                                // the original path fail timing.
                                calc_center_x = calc_x + BALL_SIZE/2;
                                calc_center_y = calc_y + BALL_SIZE/2;
                                if ((calc_center_x >= BRICK_X0) &&
                                    (calc_center_x < BRICK_X0 +
                                     BRICK_COLS*BRICK_PITCH_X) &&
                                    (calc_center_y >= BRICK_Y0) &&
                                    (calc_center_y < BRICK_Y0 +
                                     BRICK_ROWS*BRICK_PITCH_Y)) begin
                                    if (calc_center_x < BRICK_X0 + 1*BRICK_PITCH_X)
                                        calc_brick_col = 0;
                                    else if (calc_center_x < BRICK_X0 + 2*BRICK_PITCH_X)
                                        calc_brick_col = 1;
                                    else if (calc_center_x < BRICK_X0 + 3*BRICK_PITCH_X)
                                        calc_brick_col = 2;
                                    else if (calc_center_x < BRICK_X0 + 4*BRICK_PITCH_X)
                                        calc_brick_col = 3;
                                    else if (calc_center_x < BRICK_X0 + 5*BRICK_PITCH_X)
                                        calc_brick_col = 4;
                                    else if (calc_center_x < BRICK_X0 + 6*BRICK_PITCH_X)
                                        calc_brick_col = 5;
                                    else if (calc_center_x < BRICK_X0 + 7*BRICK_PITCH_X)
                                        calc_brick_col = 6;
                                    else if (calc_center_x < BRICK_X0 + 8*BRICK_PITCH_X)
                                        calc_brick_col = 7;
                                    else if (calc_center_x < BRICK_X0 + 9*BRICK_PITCH_X)
                                        calc_brick_col = 8;
                                    else
                                        calc_brick_col = 9;

                                    if (calc_center_y < BRICK_Y0 + 1*BRICK_PITCH_Y)
                                        calc_brick_row = 0;
                                    else if (calc_center_y < BRICK_Y0 + 2*BRICK_PITCH_Y)
                                        calc_brick_row = 1;
                                    else if (calc_center_y < BRICK_Y0 + 3*BRICK_PITCH_Y)
                                        calc_brick_row = 2;
                                    else if (calc_center_y < BRICK_Y0 + 4*BRICK_PITCH_Y)
                                        calc_brick_row = 3;
                                    else
                                        calc_brick_row = 4;

                                    calc_brick_index =
                                        calc_brick_row*BRICK_COLS+calc_brick_col;

                                    if ((calc_brick_index >= 0) &&
                                        (calc_brick_index < 50)) begin
                                        brick_check_index   <= calc_brick_index[5:0];
                                        brick_check_pending <= 1'b1;
                                    end
                                end

                                ball_x_live <= calc_x[10:0];
                                ball_y_live <= calc_y[9:0];
                                vx_live     <= calc_vx[5:0];
                                vy_live     <= calc_vy[5:0];

                                if (calc_y >= FIELD_BOTTOM)
                                    state_live <= ST_LIFE_LOST;
                            end
                        end
                    end

                    ST_PAUSED: begin
                        if (event_pause || event_ok)
                            state_live <= ST_RUN;
                    end

                    ST_LIFE_LOST: begin
                        if (lives_live > 3'd1) begin
                            lives_live     <= lives_live - 3'd1;
                            ball_x_live    <= paddle_x_live + BALL_X_OFFSET;
                            ball_y_live    <= BALL_Y_READY;
                            vx_live        <= 6'sd4;
                            vy_live        <= -6'sd4;
                            state_live     <= ST_READY;
                        end else begin
                            lives_live <= 3'd0;
                            state_live <= ST_OVER;
                        end
                    end

                    ST_WIN: begin
                        if (event_ok) begin
                            paddle_x_live         <= PADDLE_X_INIT;
                            brick_alive_live      <= {50{1'b1}};
                            bricks_remaining_live <= 6'd50;
                            lives_live            <= 3'd3;
                            score_live            <= 16'd0;
                            state_live            <= ST_READY;
                        end
                    end

                    ST_OVER: begin
                        if (event_ok) begin
                            paddle_x_live         <= PADDLE_X_INIT;
                            brick_alive_live      <= {50{1'b1}};
                            bricks_remaining_live <= 6'd50;
                            lives_live            <= 3'd3;
                            score_live            <= 16'd0;
                            state_live            <= ST_READY;
                        end
                    end

                    default: state_live <= ST_READY;
                endcase

                // Second pipeline stage: the address and valid bit are now
                // registered, so the dynamic brick lookup and score update
                // have a short, independent timing path.  This executes one
                // 51.2 MHz cycle (19.531 ns) after the 60 Hz movement update.
                if (brick_check_pending) begin
                    brick_check_pending <= 1'b0;

                    if ((state_live == ST_RUN) &&
                        brick_alive_live[brick_check_index]) begin
                        brick_alive_live[brick_check_index] <= 1'b0;
                        score_live <= score_live + 16'd1;
                        bricks_remaining_live <=
                            bricks_remaining_live - 6'd1;
                        vy_live <= -vy_live;

                        if (bricks_remaining_live == 6'd1)
                            state_live <= ST_WIN;
                    end
                end
            end
        end
    end

    wire in_field =
        (pixel_x >= FIELD_LEFT) && (pixel_x < FIELD_RIGHT) &&
        (pixel_y >= FIELD_TOP)  && (pixel_y < FIELD_BOTTOM);

    wire ball_pixel =
        (pixel_x >= ball_x_frame) &&
        (pixel_x <  ball_x_frame + BALL_SIZE) &&
        (pixel_y >= ball_y_frame) &&
        (pixel_y <  ball_y_frame + BALL_SIZE);

    wire paddle_pixel =
        (pixel_x >= paddle_x_frame) &&
        (pixel_x <  paddle_x_frame + PADDLE_W) &&
        (pixel_y >= PADDLE_Y) &&
        (pixel_y <  PADDLE_Y + PADDLE_H);

    wire in_brick_region =
        (pixel_x >= BRICK_X0) &&
        (pixel_x < BRICK_X0 + BRICK_COLS*BRICK_PITCH_X) &&
        (pixel_y >= BRICK_Y0) &&
        (pixel_y < BRICK_Y0 + BRICK_ROWS*BRICK_PITCH_Y);

    wire [10:0] brick_rel_x = pixel_x - BRICK_X0;
    wire [9:0]  brick_rel_y = pixel_y - BRICK_Y0;
    wire [3:0] render_brick_col = brick_rel_x / BRICK_PITCH_X;
    wire [2:0] render_brick_row = brick_rel_y / BRICK_PITCH_Y;
    wire [6:0] render_brick_index =
        render_brick_row * BRICK_COLS + render_brick_col;
    wire render_brick_inner =
        ((brick_rel_x % BRICK_PITCH_X) < BRICK_W) &&
        ((brick_rel_y % BRICK_PITCH_Y) < BRICK_H);
    wire brick_pixel = in_brick_region && render_brick_inner &&
        (render_brick_index < 50) &&
        brick_alive_frame[render_brick_index];

    integer life_i;
    always @(*) begin
        pixel_rgb = C_OUTSIDE;

        if (pixel_y < FIELD_TOP)
            pixel_rgb = C_STATUS;
        else if (in_field)
            pixel_rgb = C_FIELD;

        if (in_field &&
            ((pixel_x == FIELD_LEFT) || (pixel_x == FIELD_RIGHT-1) ||
             (pixel_y == FIELD_TOP)))
            pixel_rgb = C_BORDER;

        if (brick_pixel) begin
            case (render_brick_row)
                3'd0: pixel_rgb = C_YELLOW;
                3'd1: pixel_rgb = C_ORANGE;
                3'd2: pixel_rgb = C_RED;
                3'd3: pixel_rgb = C_PURPLE;
                default: pixel_rgb = C_CYAN;
            endcase
        end

        if (paddle_pixel)
            pixel_rgb = C_PADDLE;
        if (ball_pixel)
            pixel_rgb = C_BALL;

        // Score bar: each removed brick adds twelve pixels.
        if ((pixel_y >= 10'd24) && (pixel_y < 10'd40) &&
            (pixel_x >= FIELD_LEFT) &&
            (pixel_x < FIELD_LEFT + score_frame*12))
            pixel_rgb = C_YELLOW;

        // Three life blocks in the upper-right status area.
        for (life_i = 0; life_i < 3; life_i = life_i + 1) begin
            if ((life_i < lives_frame) &&
                (pixel_x >= 11'd790 + life_i*36) &&
                (pixel_x <  11'd814 + life_i*36) &&
                (pixel_y >= 10'd20) && (pixel_y < 10'd44))
                pixel_rgb = C_RED;
        end

        if ((state_frame == ST_READY) &&
            (pixel_x >= 11'd384) && (pixel_x < 11'd640) &&
            (pixel_y >= 10'd270) && (pixel_y < 10'd350))
            pixel_rgb = C_YELLOW;

        if ((state_frame == ST_PAUSED) &&
            (pixel_x >= 11'd384) && (pixel_x < 11'd640) &&
            (pixel_y >= 10'd270) && (pixel_y < 10'd350))
            pixel_rgb = C_YELLOW;

        if ((state_frame == ST_LIFE_LOST) &&
            (pixel_x >= 11'd360) && (pixel_x < 11'd664) &&
            (pixel_y >= 10'd260) && (pixel_y < 10'd360))
            pixel_rgb = C_ORANGE;

        if ((state_frame == ST_WIN) &&
            (pixel_x >= 11'd340) && (pixel_x < 11'd684) &&
            (pixel_y >= 10'd240) && (pixel_y < 10'd360))
            pixel_rgb = C_GREEN;

        if ((state_frame == ST_OVER) &&
            (pixel_x >= 11'd320) && (pixel_x < 11'd704) &&
            (pixel_y >= 10'd230) && (pixel_y < 10'd370))
            pixel_rgb = C_RED;
    end

endmodule
