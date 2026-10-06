`timescale 1ns/1ps

// Chapter 11: 25 x 13 grid maze.
//
// The original 800x480 teaching layout is adapted to the verified 1024x600
// panel without changing its 32x32 logical cells.  The 800x416 maze board is
// horizontally centred at X=112 and starts below the 64-pixel status bar.
module maze_game(
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

    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,

    output wire        pixel_on,
    output reg  [23:0] pixel_rgb,
    output wire [15:0] score,
    output wire [3:0]  game_state,
    output wire        exit_request
);

    localparam integer GRID_W    = 25;
    localparam integer GRID_H    = 13;
    localparam integer CELL_SIZE = 32;
    localparam integer BOARD_X0  = 112;
    localparam integer BOARD_Y0  = 64;
    localparam integer BOARD_X1  = BOARD_X0 + GRID_W * CELL_SIZE;
    localparam integer BOARD_Y1  = BOARD_Y0 + GRID_H * CELL_SIZE;

    localparam [2:0]
        CELL_ROAD  = 3'd0,
        CELL_WALL  = 3'd1,
        CELL_START = 3'd2,
        CELL_GOAL  = 3'd3;

    localparam [3:0]
        ST_READY  = 4'd0,
        ST_PLAY   = 4'd1,
        ST_PAUSED = 4'd2,
        ST_WIN    = 4'd4,
        ST_READ   = 4'd5,
        ST_CHECK  = 4'd6;

    localparam [23:0]
        C_OUTSIDE = 24'h101820,
        C_STATUS  = 24'h17212B,
        C_ROAD    = 24'h123540,
        C_WALL    = 24'h536A73,
        C_GRID    = 24'h2A5660,
        C_START   = 24'h2D8C5A,
        C_GOAL    = 24'hE05252,
        C_PLAYER  = 24'hF4F4F4,
        C_YELLOW  = 24'hE3B341,
        C_WIN     = 24'h62D394,
        C_CYAN    = 24'h2A9DAD;

    reg [4:0] player_x_live;
    reg [3:0] player_y_live;
    reg [4:0] next_x;
    reg [3:0] next_y;
    reg [15:0] move_count_live;
    reg [3:0] state_live;

    reg [4:0] player_x_frame;
    reg [3:0] player_y_frame;
    reg [15:0] move_count_frame;
    reg [3:0] state_frame;

    wire [2:0] move_cell;
    maze_map_rom u_move_map (
        .cell_x(next_x),
        .cell_y(next_y),
        .cell_data(move_cell)
    );

    wire in_board =
        (pixel_x >= BOARD_X0) && (pixel_x < BOARD_X1) &&
        (pixel_y >= BOARD_Y0) && (pixel_y < BOARD_Y1);

    wire [10:0] board_rel_x = pixel_x - BOARD_X0;
    wire [9:0]  board_rel_y = pixel_y - BOARD_Y0;
    wire [4:0] render_cell_x = board_rel_x[9:5];
    wire [3:0] render_cell_y = board_rel_y[8:5];
    wire [2:0] render_cell;

    maze_map_rom u_render_map (
        .cell_x(render_cell_x),
        .cell_y(render_cell_y),
        .cell_data(render_cell)
    );

    wire [3:0] visible_state_live =
        (state_live == ST_READY)  ? 4'd0 :
        (state_live == ST_PAUSED) ? 4'd2 :
        (state_live == ST_WIN)    ? 4'd4 : 4'd1;

    assign pixel_on     = 1'b1;
    assign score        = move_count_frame;
    assign game_state   = state_frame;
    assign exit_request = game_enable && event_back;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x_live  <= 5'd1;
            player_y_live  <= 4'd1;
            next_x         <= 5'd1;
            next_y         <= 4'd1;
            move_count_live<= 16'd0;
            state_live     <= ST_READY;

            player_x_frame <= 5'd1;
            player_y_frame <= 4'd1;
            move_count_frame <= 16'd0;
            state_frame    <= 4'd0;
        end else begin
            // One snapshot at the start of every LCD frame prevents the
            // player and state overlays from changing during active scan.
            if ((pixel_x == 11'd0) && (pixel_y == 10'd0)) begin
                player_x_frame   <= player_x_live;
                player_y_frame   <= player_y_live;
                move_count_frame <= move_count_live;
                state_frame      <= visible_state_live;
            end

            if (!game_enable) begin
                player_x_live   <= 5'd1;
                player_y_live   <= 4'd1;
                next_x          <= 5'd1;
                next_y          <= 4'd1;
                move_count_live <= 16'd0;
                state_live      <= ST_READY;
            end else begin
                case (state_live)
                    ST_READY: begin
                        if (event_ok) begin
                            player_x_live   <= 5'd1;
                            player_y_live   <= 4'd1;
                            move_count_live <= 16'd0;
                            state_live      <= ST_PLAY;
                        end
                    end

                    ST_PLAY: begin
                        if (event_pause) begin
                            state_live <= ST_PAUSED;
                        end else if (event_up || event_down ||
                                     event_left || event_right) begin
                            next_x <= player_x_live;
                            next_y <= player_y_live;

                            if (event_up && (player_y_live > 4'd0))
                                next_y <= player_y_live - 4'd1;
                            else if (event_down &&
                                     (player_y_live < GRID_H-1))
                                next_y <= player_y_live + 4'd1;
                            else if (event_left && (player_x_live > 5'd0))
                                next_x <= player_x_live - 5'd1;
                            else if (event_right &&
                                     (player_x_live < GRID_W-1))
                                next_x <= player_x_live + 5'd1;

                            state_live <= ST_READ;
                        end
                    end

                    // Keep a separate read state so the controller also works
                    // if maze_map_rom is later replaced by synchronous BRAM.
                    ST_READ: begin
                        state_live <= ST_CHECK;
                    end

                    ST_CHECK: begin
                        if (move_cell == CELL_WALL) begin
                            state_live <= ST_PLAY;
                        end else begin
                            player_x_live   <= next_x;
                            player_y_live   <= next_y;
                            move_count_live <= move_count_live + 16'd1;

                            if (move_cell == CELL_GOAL)
                                state_live <= ST_WIN;
                            else
                                state_live <= ST_PLAY;
                        end
                    end

                    ST_PAUSED: begin
                        if (event_pause)
                            state_live <= ST_PLAY;
                    end

                    ST_WIN: begin
                        if (event_ok) begin
                            player_x_live   <= 5'd1;
                            player_y_live   <= 4'd1;
                            next_x          <= 5'd1;
                            next_y          <= 4'd1;
                            move_count_live <= 16'd0;
                            state_live      <= ST_READY;
                        end
                    end

                    default: begin
                        state_live <= ST_READY;
                    end
                endcase
            end
        end
    end

    wire player_cell = in_board &&
        (render_cell_x == player_x_frame) &&
        (render_cell_y == player_y_frame);

    wire grid_line = in_board &&
        ((board_rel_x[4:0] == 5'd0) || (board_rel_y[4:0] == 5'd0));

    wire player_inner = player_cell &&
        (board_rel_x[4:0] >= 5'd6) && (board_rel_x[4:0] <= 5'd25) &&
        (board_rel_y[4:0] >= 5'd6) && (board_rel_y[4:0] <= 5'd25);

    always @(*) begin
        pixel_rgb = C_OUTSIDE;

        if (pixel_y < 10'd64)
            pixel_rgb = C_STATUS;

        if (in_board) begin
            case (render_cell)
                CELL_WALL:  pixel_rgb = C_WALL;
                CELL_START: pixel_rgb = C_START;
                CELL_GOAL:  pixel_rgb = C_GOAL;
                default:    pixel_rgb = C_ROAD;
            endcase

            if (grid_line)
                pixel_rgb = C_GRID;

            if (player_inner)
                pixel_rgb = C_PLAYER;
        end

        // Valid-move counter in the status bar.
        if ((pixel_y >= 10'd24) && (pixel_y < 10'd40) &&
            (pixel_x >= BOARD_X0) &&
            (pixel_x < BOARD_X0 + ({5'd0, move_count_frame[6:0]} << 3)))
            pixel_rgb = C_CYAN;

        if ((state_frame == 4'd0) &&
            (pixel_x >= 11'd384) && (pixel_x < 11'd640) &&
            (pixel_y >= 10'd260) && (pixel_y < 10'd340))
            pixel_rgb = C_YELLOW;

        if ((state_frame == 4'd2) &&
            (pixel_x >= 11'd384) && (pixel_x < 11'd640) &&
            (pixel_y >= 10'd260) && (pixel_y < 10'd340))
            pixel_rgb = C_YELLOW;

        if ((state_frame == 4'd4) &&
            (pixel_x >= 11'd340) && (pixel_x < 11'd684) &&
            (pixel_y >= 10'd240) && (pixel_y < 10'd360))
            pixel_rgb = C_WIN;
    end

endmodule
