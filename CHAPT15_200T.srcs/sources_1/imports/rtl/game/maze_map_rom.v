`timescale 1ns/1ps

// Chapter 11 fixed maze map.
//
// Cell encoding follows the tutorial:
//   0 = road, 1 = wall, 2 = start, 3 = goal.
// The logical map is 25 columns x 13 rows.  The alternating openings in the
// five vertical walls form a deterministic, fully synthesizable maze.
module maze_map_rom(
    input  wire [4:0] cell_x,
    input  wire [3:0] cell_y,
    output reg  [2:0] cell_data
);

    localparam [2:0]
        CELL_ROAD  = 3'd0,
        CELL_WALL  = 3'd1,
        CELL_START = 3'd2,
        CELL_GOAL  = 3'd3;

    always @(*) begin
        cell_data = CELL_ROAD;

        if ((cell_x >= 5'd25) || (cell_y >= 4'd13)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd1) && (cell_y == 4'd1)) begin
            cell_data = CELL_START;
        end
        else if ((cell_x == 5'd23) && (cell_y == 4'd11)) begin
            cell_data = CELL_GOAL;
        end
        else if ((cell_x == 5'd0) || (cell_x == 5'd24) ||
                 (cell_y == 4'd0) || (cell_y == 4'd12)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd4) &&
                 (cell_y >= 4'd1) && (cell_y <= 4'd11) &&
                 (cell_y != 4'd3)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd8) &&
                 (cell_y >= 4'd1) && (cell_y <= 4'd11) &&
                 (cell_y != 4'd9)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd12) &&
                 (cell_y >= 4'd1) && (cell_y <= 4'd11) &&
                 (cell_y != 4'd5)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd16) &&
                 (cell_y >= 4'd1) && (cell_y <= 4'd11) &&
                 (cell_y != 4'd8)) begin
            cell_data = CELL_WALL;
        end
        else if ((cell_x == 5'd20) &&
                 (cell_y >= 4'd1) && (cell_y <= 4'd11) &&
                 (cell_y != 4'd4)) begin
            cell_data = CELL_WALL;
        end
    end

endmodule
