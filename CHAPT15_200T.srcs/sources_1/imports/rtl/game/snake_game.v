`timescale 1ns/1ps

// Chapter 10: snake game.
//
// Tutorial rules retained:
//   - 25 x 13 logical grid;
//   - 32 x 32 pixels per cell;
//   - 64-pixel status bar;
//   - up to 128 snake segments;
//   - multi-cycle body shift and self-collision scan;
//   - READY, RUN, PAUSE and DEAD states;
//   - food growth and score update.
//
// The original 800x480 board is horizontally centred on the verified
// 1024x600 LCD.  The logical game remains exactly 800x416 pixels.
module snake_game #(
    parameter integer MOVE_TICK_DIV = 10,
    parameter [4:0] FOOD_X_INIT = 5'd18,
    parameter [3:0] FOOD_Y_INIT = 4'd8
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

    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,

    output wire        pixel_on,
    output reg  [23:0] pixel_rgb,
    output wire [15:0] score,
    output wire [3:0]  game_state,
    output wire        exit_request
);

    localparam integer GRID_W   = 25;
    localparam integer GRID_H   = 13;
    localparam integer CELL_SIZE= 32;
    localparam integer MAX_LEN  = 128;
    localparam integer STATUS_H = 64;
    localparam integer BOARD_X0 = 112;
    localparam integer BOARD_Y0 = 64;
    localparam integer BOARD_X1 = BOARD_X0 + GRID_W * CELL_SIZE;
    localparam integer BOARD_Y1 = BOARD_Y0 + GRID_H * CELL_SIZE;

    localparam [2:0]
        DIR_UP    = 3'd0,
        DIR_DOWN  = 3'd1,
        DIR_LEFT  = 3'd2,
        DIR_RIGHT = 3'd3;

    localparam [3:0]
        SM_READY   = 4'd0,
        SM_RUN     = 4'd1,
        SM_SHIFT   = 4'd2,
        SM_CHECK   = 4'd3,
        SM_EAT     = 4'd4,
        SM_RESPAWN = 4'd5,
        SM_PAUSED  = 4'd6,
        SM_DEAD    = 4'd7;

    localparam [3:0]
        VIEW_READY  = 4'd0,
        VIEW_RUN    = 4'd1,
        VIEW_PAUSED = 4'd2,
        VIEW_DEAD   = 4'd4;

    localparam [23:0]
        C_OUTSIDE = 24'h101820,
        C_STATUS  = 24'h17212B,
        C_BOARD   = 24'h173B2E,
        C_GRID    = 24'h285544,
        C_BORDER  = 24'h6BCB9A,
        C_HEAD    = 24'hF4F4F4,
        C_BODY    = 24'h62D394,
        C_FOOD    = 24'hFF5A4F,
        C_GOLD    = 24'hE3B341,
        C_CYAN    = 24'h2A9DAD,
        C_DEAD    = 24'hA83A3A;

    reg [4:0] snake_x [0:MAX_LEN-1];
    reg [3:0] snake_y [0:MAX_LEN-1];
    reg [7:0] snake_len;

    reg [4:0] food_x;
    reg [3:0] food_y;
    reg [15:0] score_live;
    reg [3:0] state_live;

    reg [2:0] direction;
    reg [2:0] pending_direction;
    reg       turn_locked;
    reg [7:0] move_div_count;

    reg [4:0] new_head_x;
    reg [3:0] new_head_y;
    reg [4:0] old_tail_x;
    reg [3:0] old_tail_y;
    reg [7:0] shift_index;
    reg [7:0] check_index;
    reg       collision_seen;

    reg [4:0] respawn_x;
    reg [3:0] respawn_y;
    reg [7:0] respawn_index;
    reg       respawn_occupied;
    reg [15:0] lfsr;

    // Complete frame snapshots prevent segment updates from tearing the LCD.
    reg [4:0] snake_x_frame [0:MAX_LEN-1];
    reg [3:0] snake_y_frame [0:MAX_LEN-1];
    reg [7:0] snake_len_frame;
    reg [4:0] food_x_frame;
    reg [3:0] food_y_frame;
    reg [15:0] score_frame;
    reg [3:0] state_frame;

    integer i_state;
    integer i_render;

    wire [3:0] visible_state_live =
        (state_live == SM_READY)  ? VIEW_READY  :
        (state_live == SM_PAUSED) ? VIEW_PAUSED :
        (state_live == SM_DEAD)   ? VIEW_DEAD   : VIEW_RUN;

    reg [2:0] accepted_direction;
    always @(*) begin
        accepted_direction = pending_direction;
        if (!turn_locked) begin
            if (event_up && direction != DIR_DOWN)
                accepted_direction = DIR_UP;
            else if (event_down && direction != DIR_UP)
                accepted_direction = DIR_DOWN;
            else if (event_left && direction != DIR_RIGHT)
                accepted_direction = DIR_LEFT;
            else if (event_right && direction != DIR_LEFT)
                accepted_direction = DIR_RIGHT;
        end
    end

    reg [4:0] candidate_head_x;
    reg [3:0] candidate_head_y;
    reg       candidate_wall_hit;
    always @(*) begin
        candidate_head_x = snake_x[0];
        candidate_head_y = snake_y[0];
        candidate_wall_hit = 1'b0;

        case (accepted_direction)
            DIR_UP: begin
                if (snake_y[0] == 4'd0)
                    candidate_wall_hit = 1'b1;
                else
                    candidate_head_y = snake_y[0] - 4'd1;
            end
            DIR_DOWN: begin
                if (snake_y[0] == GRID_H-1)
                    candidate_wall_hit = 1'b1;
                else
                    candidate_head_y = snake_y[0] + 4'd1;
            end
            DIR_LEFT: begin
                if (snake_x[0] == 5'd0)
                    candidate_wall_hit = 1'b1;
                else
                    candidate_head_x = snake_x[0] - 5'd1;
            end
            default: begin
                if (snake_x[0] == GRID_W-1)
                    candidate_wall_hit = 1'b1;
                else
                    candidate_head_x = snake_x[0] + 5'd1;
            end
        endcase
    end

    wire check_match =
        (snake_x[check_index] == snake_x[0]) &&
        (snake_y[check_index] == snake_y[0]);

    wire respawn_match =
        (snake_x[respawn_index] == respawn_x) &&
        (snake_y[respawn_index] == respawn_y);

    assign pixel_on     = 1'b1;
    assign score        = score_frame;
    assign game_state   = state_frame;
    assign exit_request = game_enable && event_back;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snake_len        <= 8'd4;
            food_x           <= FOOD_X_INIT;
            food_y           <= FOOD_Y_INIT;
            score_live       <= 16'd0;
            state_live       <= SM_READY;
            direction        <= DIR_RIGHT;
            pending_direction<= DIR_RIGHT;
            turn_locked      <= 1'b0;
            move_div_count    <= 8'd0;
            new_head_x       <= 5'd0;
            new_head_y       <= 4'd0;
            old_tail_x       <= 5'd0;
            old_tail_y       <= 4'd0;
            shift_index      <= 8'd0;
            check_index      <= 8'd1;
            collision_seen   <= 1'b0;
            respawn_x        <= 5'd0;
            respawn_y        <= 4'd0;
            respawn_index    <= 8'd0;
            respawn_occupied <= 1'b0;
            lfsr             <= 16'h1ACE;

            snake_len_frame  <= 8'd4;
            food_x_frame     <= FOOD_X_INIT;
            food_y_frame     <= FOOD_Y_INIT;
            score_frame      <= 16'd0;
            state_frame      <= VIEW_READY;

            for (i_state = 0; i_state < MAX_LEN; i_state = i_state + 1) begin
                snake_x[i_state]       <= 5'd0;
                snake_y[i_state]       <= 4'd0;
                snake_x_frame[i_state] <= 5'd0;
                snake_y_frame[i_state] <= 4'd0;
            end

            snake_x[0] <= 5'd6; snake_y[0] <= 4'd6;
            snake_x[1] <= 5'd5; snake_y[1] <= 4'd6;
            snake_x[2] <= 5'd4; snake_y[2] <= 4'd6;
            snake_x[3] <= 5'd3; snake_y[3] <= 4'd6;
            snake_x_frame[0] <= 5'd6; snake_y_frame[0] <= 4'd6;
            snake_x_frame[1] <= 5'd5; snake_y_frame[1] <= 4'd6;
            snake_x_frame[2] <= 5'd4; snake_y_frame[2] <= 4'd6;
            snake_x_frame[3] <= 5'd3; snake_y_frame[3] <= 4'd6;
        end else begin
            // x^16 + x^14 + x^13 + x^11 + 1
            lfsr <= {lfsr[14:0],
                     lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            // The timing generator exposes pixel 0,0 once per frame.
            if ((pixel_x == 11'd0) && (pixel_y == 10'd0)) begin
                snake_len_frame <= snake_len;
                food_x_frame    <= food_x;
                food_y_frame    <= food_y;
                score_frame     <= score_live;
                state_frame     <= visible_state_live;
                for (i_state = 0; i_state < MAX_LEN; i_state = i_state + 1) begin
                    snake_x_frame[i_state] <= snake_x[i_state];
                    snake_y_frame[i_state] <= snake_y[i_state];
                end
            end

            if (!game_enable) begin
                snake_len         <= 8'd4;
                snake_x[0]        <= 5'd6; snake_y[0] <= 4'd6;
                snake_x[1]        <= 5'd5; snake_y[1] <= 4'd6;
                snake_x[2]        <= 5'd4; snake_y[2] <= 4'd6;
                snake_x[3]        <= 5'd3; snake_y[3] <= 4'd6;
                food_x            <= FOOD_X_INIT;
                food_y            <= FOOD_Y_INIT;
                score_live        <= 16'd0;
                state_live        <= SM_READY;
                direction         <= DIR_RIGHT;
                pending_direction <= DIR_RIGHT;
                turn_locked       <= 1'b0;
                move_div_count     <= 8'd0;
            end else begin
                case (state_live)
                    SM_READY: begin
                        if (event_ok) begin
                            state_live        <= SM_RUN;
                            direction         <= DIR_RIGHT;
                            pending_direction <= DIR_RIGHT;
                            turn_locked       <= 1'b0;
                            move_div_count     <= 8'd0;
                        end
                    end

                    SM_RUN: begin
                        if (event_pause) begin
                            state_live     <= SM_PAUSED;
                            turn_locked   <= 1'b0;
                            move_div_count <= 8'd0;
                        end else begin
                            if (!turn_locked &&
                                accepted_direction != pending_direction) begin
                                pending_direction <= accepted_direction;
                                turn_locked <= 1'b1;
                            end

                            if (game_tick) begin
                                if (move_div_count == MOVE_TICK_DIV-1) begin
                                    move_div_count <= 8'd0;
                                    direction <= accepted_direction;
                                    pending_direction <= accepted_direction;
                                    turn_locked <= 1'b0;

                                    if (candidate_wall_hit) begin
                                        state_live <= SM_DEAD;
                                    end else begin
                                        new_head_x  <= candidate_head_x;
                                        new_head_y  <= candidate_head_y;
                                        old_tail_x  <= snake_x[snake_len-1];
                                        old_tail_y  <= snake_y[snake_len-1];
                                        shift_index <= snake_len - 8'd1;
                                        state_live  <= SM_SHIFT;
                                    end
                                end else begin
                                    move_div_count <= move_div_count + 8'd1;
                                end
                            end
                        end
                    end

                    SM_SHIFT: begin
                        if (shift_index != 0) begin
                            snake_x[shift_index] <= snake_x[shift_index-1];
                            snake_y[shift_index] <= snake_y[shift_index-1];
                            shift_index <= shift_index - 8'd1;
                        end else begin
                            snake_x[0] <= new_head_x;
                            snake_y[0] <= new_head_y;
                            check_index <= 8'd1;
                            collision_seen <= 1'b0;
                            state_live <= SM_CHECK;
                        end
                    end

                    SM_CHECK: begin
                        if (check_index < snake_len) begin
                            if (check_match)
                                collision_seen <= 1'b1;

                            if (check_index == snake_len-1) begin
                                if (collision_seen || check_match) begin
                                    state_live <= SM_DEAD;
                                end else if ((snake_x[0] == food_x) &&
                                             (snake_y[0] == food_y)) begin
                                    state_live <= SM_EAT;
                                end else begin
                                    state_live <= SM_RUN;
                                end
                            end else begin
                                check_index <= check_index + 8'd1;
                            end
                        end else begin
                            state_live <= SM_RUN;
                        end
                    end

                    SM_EAT: begin
                        score_live <= score_live + 16'd1;
                        if (snake_len < MAX_LEN) begin
                            snake_x[snake_len] <= old_tail_x;
                            snake_y[snake_len] <= old_tail_y;
                            snake_len <= snake_len + 8'd1;
                        end

                        respawn_x <= (lfsr[4:0] >= GRID_W) ?
                                     lfsr[4:0] - GRID_W : lfsr[4:0];
                        respawn_y <= (lfsr[8:5] >= GRID_H) ?
                                     lfsr[8:5] - GRID_H : lfsr[8:5];
                        respawn_index <= 8'd0;
                        respawn_occupied <= 1'b0;
                        state_live <= SM_RESPAWN;
                    end

                    SM_RESPAWN: begin
                        if (respawn_index < snake_len) begin
                            if (respawn_match)
                                respawn_occupied <= 1'b1;

                            if (respawn_index == snake_len-1) begin
                                if (respawn_occupied || respawn_match) begin
                                    if (respawn_x == GRID_W-1) begin
                                        respawn_x <= 5'd0;
                                        respawn_y <= (respawn_y == GRID_H-1) ?
                                                     4'd0 : respawn_y + 4'd1;
                                    end else begin
                                        respawn_x <= respawn_x + 5'd1;
                                    end
                                    respawn_index <= 8'd0;
                                    respawn_occupied <= 1'b0;
                                end else begin
                                    food_x <= respawn_x;
                                    food_y <= respawn_y;
                                    state_live <= SM_RUN;
                                end
                            end else begin
                                respawn_index <= respawn_index + 8'd1;
                            end
                        end else begin
                            food_x <= respawn_x;
                            food_y <= respawn_y;
                            state_live <= SM_RUN;
                        end
                    end

                    SM_PAUSED: begin
                        if (event_pause || event_ok) begin
                            state_live <= SM_RUN;
                            move_div_count <= 8'd0;
                        end
                    end

                    SM_DEAD: begin
                        if (event_ok) begin
                            snake_len         <= 8'd4;
                            snake_x[0]        <= 5'd6; snake_y[0] <= 4'd6;
                            snake_x[1]        <= 5'd5; snake_y[1] <= 4'd6;
                            snake_x[2]        <= 5'd4; snake_y[2] <= 4'd6;
                            snake_x[3]        <= 5'd3; snake_y[3] <= 4'd6;
                            food_x            <= FOOD_X_INIT;
                            food_y            <= FOOD_Y_INIT;
                            score_live        <= 16'd0;
                            direction         <= DIR_RIGHT;
                            pending_direction <= DIR_RIGHT;
                            turn_locked       <= 1'b0;
                            move_div_count     <= 8'd0;
                            state_live        <= SM_READY;
                        end
                    end

                    default: state_live <= SM_READY;
                endcase
            end
        end
    end

    wire board_pixel =
        (pixel_x >= BOARD_X0) && (pixel_x < BOARD_X1) &&
        (pixel_y >= BOARD_Y0) && (pixel_y < BOARD_Y1);
    wire [10:0] board_rel_x = pixel_x - BOARD_X0;
    wire [9:0]  board_rel_y = pixel_y - BOARD_Y0;
    wire [4:0] pixel_cell_x = board_rel_x[9:5];
    wire [3:0] pixel_cell_y = board_rel_y[8:5];
    wire grid_pixel = board_pixel &&
        ((board_rel_x[4:0] == 5'd0) || (board_rel_y[4:0] == 5'd0));
    wire border_pixel =
        ((pixel_x == BOARD_X0-1) || (pixel_x == BOARD_X1)) &&
        (pixel_y >= BOARD_Y0-1) && (pixel_y <= BOARD_Y1) ||
        ((pixel_y == BOARD_Y0-1) || (pixel_y == BOARD_Y1)) &&
        (pixel_x >= BOARD_X0-1) && (pixel_x <= BOARD_X1);
    wire head_pixel = board_pixel &&
        (pixel_cell_x == snake_x_frame[0]) &&
        (pixel_cell_y == snake_y_frame[0]);
    wire food_pixel = board_pixel &&
        (pixel_cell_x == food_x_frame) &&
        (pixel_cell_y == food_y_frame);

    reg body_pixel;
    always @(*) begin
        body_pixel = 1'b0;
        for (i_render = 1; i_render < MAX_LEN; i_render = i_render + 1) begin
            if ((i_render < snake_len_frame) && board_pixel &&
                (pixel_cell_x == snake_x_frame[i_render]) &&
                (pixel_cell_y == snake_y_frame[i_render]))
                body_pixel = 1'b1;
        end
    end

    wire chapter_mark =
        (pixel_x >= 11'd20) && (pixel_x < 11'd116) &&
        (pixel_y >= 10'd12) && (pixel_y < 10'd50);
    wire [10:0] score_width = {score_frame[5:0], 4'b0000};
    wire score_bar =
        (pixel_x >= 11'd160) && (pixel_x < 11'd160 + score_width) &&
        (pixel_y >= 10'd12) && (pixel_y < 10'd26);
    wire length_bar =
        (pixel_x >= 11'd160) &&
        (pixel_x < 11'd160 + {snake_len_frame[6:0], 3'b000}) &&
        (pixel_y >= 10'd36) && (pixel_y < 10'd50);

    wire ready_box =
        (pixel_x >= 11'd360) && (pixel_x < 11'd664) &&
        (pixel_y >= 10'd238) && (pixel_y < 10'd342);
    wire pause_box =
        (pixel_x >= 11'd400) && (pixel_x < 11'd624) &&
        (pixel_y >= 10'd250) && (pixel_y < 10'd330);
    wire dead_box =
        (pixel_x >= 11'd352) && (pixel_x < 11'd672) &&
        (pixel_y >= 10'd234) && (pixel_y < 10'd346);

    always @(*) begin
        pixel_rgb = C_OUTSIDE;

        if (pixel_y < STATUS_H)
            pixel_rgb = C_STATUS;
        if (board_pixel)
            pixel_rgb = C_BOARD;
        if (grid_pixel)
            pixel_rgb = C_GRID;
        if (border_pixel)
            pixel_rgb = C_BORDER;
        if (chapter_mark || score_bar)
            pixel_rgb = C_GOLD;
        if (length_bar)
            pixel_rgb = C_CYAN;

        if ((state_frame == VIEW_RUN || state_frame == VIEW_PAUSED) &&
            food_pixel)
            pixel_rgb = C_FOOD;
        if ((state_frame == VIEW_RUN || state_frame == VIEW_PAUSED) &&
            body_pixel)
            pixel_rgb = C_BODY;
        if ((state_frame == VIEW_RUN || state_frame == VIEW_PAUSED) &&
            head_pixel)
            pixel_rgb = C_HEAD;

        if ((state_frame == VIEW_READY) && ready_box)
            pixel_rgb = C_GOLD;
        if ((state_frame == VIEW_PAUSED) && pause_box)
            pixel_rgb = C_GOLD;
        if ((state_frame == VIEW_DEAD) && dead_box)
            pixel_rgb = C_DEAD;
    end

endmodule
