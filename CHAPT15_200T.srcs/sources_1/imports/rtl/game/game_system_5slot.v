`timescale 1ns/1ps

// Chapter-13 game system.  Slots 1..4 retain the verified Chapter-9 treasure,
// Chapter-10 snake, Chapter-11 maze and Chapter-12 brick-breaker games.
// Slot 5 (ui_state=6) is the Chapter-13 touch/mouse paint board.
module game_system_5slot(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  ui_state_control,
    input  wire [2:0]  ui_state_frame,
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
    output reg         pixel_on,
    output reg  [23:0] pixel_rgb,
    output reg  [15:0] score,
    output reg  [3:0]  game_state,
    output wire        exit_request
);

    wire [4:0] enable = {
        ui_state_control == 3'd6,
        ui_state_control == 3'd5,
        ui_state_control == 3'd4,
        ui_state_control == 3'd3,
        ui_state_control == 3'd2
    };

    wire [4:0]  slot_on;
    wire [23:0] slot_rgb0, slot_rgb1, slot_rgb2, slot_rgb3, slot_rgb4;
    wire [15:0] slot_score0, slot_score1, slot_score2, slot_score3, slot_score4;
    wire [3:0]  slot_state0, slot_state1, slot_state2, slot_state3, slot_state4;
    wire [4:0]  slot_exit;

    treasure_game u_game1_treasure (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[0]),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .game_tick(game_tick), .tick_1s(tick_1s),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[0]), .pixel_rgb(slot_rgb0),
        .score(slot_score0), .game_state(slot_state0),
        .exit_request(slot_exit[0])
    );

    snake_game u_game2_snake (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[1]),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause), .game_tick(game_tick),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[1]), .pixel_rgb(slot_rgb1),
        .score(slot_score1), .game_state(slot_state1),
        .exit_request(slot_exit[1])
    );

    maze_game u_game3_maze (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[2]),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[2]), .pixel_rgb(slot_rgb2),
        .score(slot_score2), .game_state(slot_state2),
        .exit_request(slot_exit[2])
    );

    breakout_game u_game4_breakout (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[3]),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause), .game_tick(game_tick),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[3]), .pixel_rgb(slot_rgb3),
        .score(slot_score3), .game_state(slot_state3),
        .exit_request(slot_exit[3])
    );

    paint_board u_game5_paint (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[4]),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[4]), .pixel_rgb(slot_rgb4),
        .score(slot_score4), .game_state(slot_state4),
        .exit_request(slot_exit[4])
    );

    assign exit_request = |slot_exit;

    always @(*) begin
        pixel_on  = 1'b0;
        pixel_rgb = 24'h000000;
        score     = 16'd0;
        game_state= 4'd0;

        case (ui_state_frame)
            3'd2: begin pixel_on=slot_on[0]; pixel_rgb=slot_rgb0; score=slot_score0; game_state=slot_state0; end
            3'd3: begin pixel_on=slot_on[1]; pixel_rgb=slot_rgb1; score=slot_score1; game_state=slot_state1; end
            3'd4: begin pixel_on=slot_on[2]; pixel_rgb=slot_rgb2; score=slot_score2; game_state=slot_state2; end
            3'd5: begin pixel_on=slot_on[3]; pixel_rgb=slot_rgb3; score=slot_score3; game_state=slot_state3; end
            3'd6: begin pixel_on=slot_on[4]; pixel_rgb=slot_rgb4; score=slot_score4; game_state=slot_state4; end
            default: begin pixel_on=1'b0; pixel_rgb=24'h000000; score=16'd0; game_state=4'd0; end
        endcase
    end

endmodule
