`timescale 1ns/1ps

// Chapter-8/15 renderer with lightweight built-in 5x7 ASCII text overlay.
// The labels are synthesized as LUT logic; no extra font BRAM/IP is needed.
module chapter8_ui_renderer_1024x600(
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        active_video,
    input  wire [2:0]  ui_state,
    input  wire [2:0]  menu_sel,
    input  wire [3:0]  keypad_code,
    input  wire        keypad_valid_latched,
    input  wire [7:0]  keyboard_code,
    input  wire        keyboard_extended,
    input  wire [4:0]  ec_count,
    input  wire [10:0] pointer_x,
    input  wire [9:0]  pointer_y,
    input  wire        pointer_visible,
    input  wire        ft_flag,
    input  wire        game_pixel_on,
    input  wire [23:0] game_pixel_rgb,
    input  wire [15:0] game_score,
    input  wire [3:0]  game_state,
    output reg  [23:0] rgb
);

    localparam [23:0]
        C_BLACK  = 24'h101820,
        C_WHITE  = 24'hF4F4F4,
        C_BLUE   = 24'h2457A7,
        C_GREEN  = 24'h2D8C5A,
        C_RED    = 24'hA83A3A,
        C_YELLOW = 24'hE3B341,
        C_GRAY   = 24'h5E6870,
        C_CYAN   = 24'h2A9DAD,
        C_PURPLE = 24'h6D4AA5;

    localparam [5:0]
        T_HOME_TITLE=6'd0, T_MENU_INPUT=6'd1, T_MENU_TREASURE=6'd2,
        T_MENU_SNAKE=6'd3, T_MENU_MAZE=6'd4, T_MENU_BREAKOUT=6'd5,
        T_MENU_PAINT=6'd6, T_MENU_INFO=6'd7, T_HOME_HELP=6'd8,
        T_KEYPAD=6'd9, T_EC11=6'd10, T_PS2=6'd11, T_TOUCH=6'd12,
        T_FT_TOUCH=6'd13, T_GT_TOUCH=6'd14, T_SCORE=6'd15,
        T_MOVES=6'd16, T_STATE=6'd17, T_READY=6'd18, T_RUN=6'd19,
        T_PAUSED=6'd20, T_GAME_OVER=6'd21, T_WIN=6'd22,
        T_LIFE_LOST=6'd23, T_HIT=6'd24, T_COLOR=6'd25, T_ERASE=6'd26,
        T_CLEAR=6'd27, T_DRAW_COUNT=6'd28, T_PAINT_HELP=6'd29,
        T_GAME_HELP=6'd30, T_INFO_TITLE=6'd31, T_INFO_PLATFORM=6'd32,
        T_INFO_INPUT=6'd33, T_INFO_GAMES=6'd34, T_BACK_RETURN=6'd35,
        T_LIVES=6'd36, T_EXT=6'd37, T_NORMAL=6'd38, T_HEX=6'd39;

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (ch)
                8'h41: begin // A
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11111;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h42: begin // B
                    case (row)
                        3'd0: glyph_row = 5'b11110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b11110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h43: begin // C
                    case (row)
                        3'd0: glyph_row = 5'b01111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b10000;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b01111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h44: begin // D
                    case (row)
                        3'd0: glyph_row = 5'b11110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b11110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h45: begin // E
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b11111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h46: begin // F
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b10000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h47: begin // G
                    case (row)
                        3'd0: glyph_row = 5'b01111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b10111;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h48: begin // H
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11111;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h49: begin // I
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b00100;
                        3'd2: glyph_row = 5'b00100;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b11111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4A: begin // J
                    case (row)
                        3'd0: glyph_row = 5'b00111;
                        3'd1: glyph_row = 5'b00010;
                        3'd2: glyph_row = 5'b00010;
                        3'd3: glyph_row = 5'b00010;
                        3'd4: glyph_row = 5'b10010;
                        3'd5: glyph_row = 5'b10010;
                        3'd6: glyph_row = 5'b01100;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4B: begin // K
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10010;
                        3'd2: glyph_row = 5'b10100;
                        3'd3: glyph_row = 5'b11000;
                        3'd4: glyph_row = 5'b10100;
                        3'd5: glyph_row = 5'b10010;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4C: begin // L
                    case (row)
                        3'd0: glyph_row = 5'b10000;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b10000;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b11111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4D: begin // M
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b11011;
                        3'd2: glyph_row = 5'b10101;
                        3'd3: glyph_row = 5'b10101;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4E: begin // N
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b11001;
                        3'd2: glyph_row = 5'b10101;
                        3'd3: glyph_row = 5'b10011;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h4F: begin // O
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h50: begin // P
                    case (row)
                        3'd0: glyph_row = 5'b11110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b10000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h51: begin // Q
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10101;
                        3'd5: glyph_row = 5'b10010;
                        3'd6: glyph_row = 5'b01101;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h52: begin // R
                    case (row)
                        3'd0: glyph_row = 5'b11110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10100;
                        3'd5: glyph_row = 5'b10010;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h53: begin // S
                    case (row)
                        3'd0: glyph_row = 5'b01111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b01110;
                        3'd4: glyph_row = 5'b00001;
                        3'd5: glyph_row = 5'b00001;
                        3'd6: glyph_row = 5'b11110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h54: begin // T
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b00100;
                        3'd2: glyph_row = 5'b00100;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b00100;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h55: begin // U
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h56: begin // V
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b01010;
                        3'd6: glyph_row = 5'b00100;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h57: begin // W
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10101;
                        3'd4: glyph_row = 5'b10101;
                        3'd5: glyph_row = 5'b10101;
                        3'd6: glyph_row = 5'b01010;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h58: begin // X
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b01010;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b01010;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h59: begin // Y
                    case (row)
                        3'd0: glyph_row = 5'b10001;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b01010;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b00100;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h5A: begin // Z
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b00001;
                        3'd2: glyph_row = 5'b00010;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b01000;
                        3'd5: glyph_row = 5'b10000;
                        3'd6: glyph_row = 5'b11111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h30: begin // 0
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10011;
                        3'd3: glyph_row = 5'b10101;
                        3'd4: glyph_row = 5'b11001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h31: begin // 1
                    case (row)
                        3'd0: glyph_row = 5'b00100;
                        3'd1: glyph_row = 5'b01100;
                        3'd2: glyph_row = 5'b00100;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h32: begin // 2
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b00001;
                        3'd3: glyph_row = 5'b00010;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b01000;
                        3'd6: glyph_row = 5'b11111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h33: begin // 3
                    case (row)
                        3'd0: glyph_row = 5'b11110;
                        3'd1: glyph_row = 5'b00001;
                        3'd2: glyph_row = 5'b00001;
                        3'd3: glyph_row = 5'b01110;
                        3'd4: glyph_row = 5'b00001;
                        3'd5: glyph_row = 5'b00001;
                        3'd6: glyph_row = 5'b11110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h34: begin // 4
                    case (row)
                        3'd0: glyph_row = 5'b00010;
                        3'd1: glyph_row = 5'b00110;
                        3'd2: glyph_row = 5'b01010;
                        3'd3: glyph_row = 5'b10010;
                        3'd4: glyph_row = 5'b11111;
                        3'd5: glyph_row = 5'b00010;
                        3'd6: glyph_row = 5'b00010;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h35: begin // 5
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b00001;
                        3'd5: glyph_row = 5'b00001;
                        3'd6: glyph_row = 5'b11110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h36: begin // 6
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10000;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b11110;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h37: begin // 7
                    case (row)
                        3'd0: glyph_row = 5'b11111;
                        3'd1: glyph_row = 5'b00001;
                        3'd2: glyph_row = 5'b00010;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b01000;
                        3'd5: glyph_row = 5'b01000;
                        3'd6: glyph_row = 5'b01000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h38: begin // 8
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b01110;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h39: begin // 9
                    case (row)
                        3'd0: glyph_row = 5'b01110;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b01111;
                        3'd4: glyph_row = 5'b00001;
                        3'd5: glyph_row = 5'b00001;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h2D: begin // -
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b00000;
                        3'd2: glyph_row = 5'b00000;
                        3'd3: glyph_row = 5'b11111;
                        3'd4: glyph_row = 5'b00000;
                        3'd5: glyph_row = 5'b00000;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h3A: begin // :
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b00100;
                        3'd2: glyph_row = 5'b00100;
                        3'd3: glyph_row = 5'b00000;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h2E: begin // .
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b00000;
                        3'd2: glyph_row = 5'b00000;
                        3'd3: glyph_row = 5'b00000;
                        3'd4: glyph_row = 5'b00000;
                        3'd5: glyph_row = 5'b00110;
                        3'd6: glyph_row = 5'b00110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h2F: begin // /
                    case (row)
                        3'd0: glyph_row = 5'b00001;
                        3'd1: glyph_row = 5'b00010;
                        3'd2: glyph_row = 5'b00010;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b01000;
                        3'd5: glyph_row = 5'b01000;
                        3'd6: glyph_row = 5'b10000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                default: glyph_row = 5'b00000;
            endcase
        end
    endfunction

    function [7:0] text_char;
        input [5:0] tid;
        input [5:0] ci;
        begin
            text_char = 8'h20;
            case (tid)
                6'd0: begin
                    case (ci)
                        6'd0: text_char = 8'h47;
                        6'd1: text_char = 8'h58;
                        6'd2: text_char = 8'h2D;
                        6'd3: text_char = 8'h42;
                        6'd4: text_char = 8'h49;
                        6'd5: text_char = 8'h44;
                        6'd6: text_char = 8'h54;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h46;
                        6'd9: text_char = 8'h50;
                        6'd10: text_char = 8'h47;
                        6'd11: text_char = 8'h41;
                        6'd12: text_char = 8'h20;
                        6'd13: text_char = 8'h47;
                        6'd14: text_char = 8'h41;
                        6'd15: text_char = 8'h4D;
                        6'd16: text_char = 8'h45;
                        6'd17: text_char = 8'h20;
                        6'd18: text_char = 8'h53;
                        6'd19: text_char = 8'h59;
                        6'd20: text_char = 8'h53;
                        6'd21: text_char = 8'h54;
                        6'd22: text_char = 8'h45;
                        6'd23: text_char = 8'h4D;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd1: begin
                    case (ci)
                        6'd0: text_char = 8'h31;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h49;
                        6'd3: text_char = 8'h4E;
                        6'd4: text_char = 8'h50;
                        6'd5: text_char = 8'h55;
                        6'd6: text_char = 8'h54;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h4D;
                        6'd9: text_char = 8'h4F;
                        6'd10: text_char = 8'h4E;
                        6'd11: text_char = 8'h49;
                        6'd12: text_char = 8'h54;
                        6'd13: text_char = 8'h4F;
                        6'd14: text_char = 8'h52;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd2: begin
                    case (ci)
                        6'd0: text_char = 8'h32;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h54;
                        6'd3: text_char = 8'h52;
                        6'd4: text_char = 8'h45;
                        6'd5: text_char = 8'h41;
                        6'd6: text_char = 8'h53;
                        6'd7: text_char = 8'h55;
                        6'd8: text_char = 8'h52;
                        6'd9: text_char = 8'h45;
                        6'd10: text_char = 8'h20;
                        6'd11: text_char = 8'h48;
                        6'd12: text_char = 8'h55;
                        6'd13: text_char = 8'h4E;
                        6'd14: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd3: begin
                    case (ci)
                        6'd0: text_char = 8'h33;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h53;
                        6'd3: text_char = 8'h4E;
                        6'd4: text_char = 8'h41;
                        6'd5: text_char = 8'h4B;
                        6'd6: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd4: begin
                    case (ci)
                        6'd0: text_char = 8'h34;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h4D;
                        6'd3: text_char = 8'h41;
                        6'd4: text_char = 8'h5A;
                        6'd5: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd5: begin
                    case (ci)
                        6'd0: text_char = 8'h35;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h42;
                        6'd3: text_char = 8'h52;
                        6'd4: text_char = 8'h45;
                        6'd5: text_char = 8'h41;
                        6'd6: text_char = 8'h4B;
                        6'd7: text_char = 8'h4F;
                        6'd8: text_char = 8'h55;
                        6'd9: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd6: begin
                    case (ci)
                        6'd0: text_char = 8'h36;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h50;
                        6'd3: text_char = 8'h41;
                        6'd4: text_char = 8'h49;
                        6'd5: text_char = 8'h4E;
                        6'd6: text_char = 8'h54;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h42;
                        6'd9: text_char = 8'h4F;
                        6'd10: text_char = 8'h41;
                        6'd11: text_char = 8'h52;
                        6'd12: text_char = 8'h44;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd7: begin
                    case (ci)
                        6'd0: text_char = 8'h37;
                        6'd1: text_char = 8'h20;
                        6'd2: text_char = 8'h53;
                        6'd3: text_char = 8'h59;
                        6'd4: text_char = 8'h53;
                        6'd5: text_char = 8'h54;
                        6'd6: text_char = 8'h45;
                        6'd7: text_char = 8'h4D;
                        6'd8: text_char = 8'h20;
                        6'd9: text_char = 8'h49;
                        6'd10: text_char = 8'h4E;
                        6'd11: text_char = 8'h46;
                        6'd12: text_char = 8'h4F;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd8: begin
                    case (ci)
                        6'd0: text_char = 8'h55;
                        6'd1: text_char = 8'h50;
                        6'd2: text_char = 8'h20;
                        6'd3: text_char = 8'h44;
                        6'd4: text_char = 8'h4F;
                        6'd5: text_char = 8'h57;
                        6'd6: text_char = 8'h4E;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h53;
                        6'd9: text_char = 8'h45;
                        6'd10: text_char = 8'h4C;
                        6'd11: text_char = 8'h45;
                        6'd12: text_char = 8'h43;
                        6'd13: text_char = 8'h54;
                        6'd14: text_char = 8'h20;
                        6'd15: text_char = 8'h20;
                        6'd16: text_char = 8'h20;
                        6'd17: text_char = 8'h4F;
                        6'd18: text_char = 8'h4B;
                        6'd19: text_char = 8'h20;
                        6'd20: text_char = 8'h45;
                        6'd21: text_char = 8'h4E;
                        6'd22: text_char = 8'h54;
                        6'd23: text_char = 8'h45;
                        6'd24: text_char = 8'h52;
                        6'd25: text_char = 8'h20;
                        6'd26: text_char = 8'h20;
                        6'd27: text_char = 8'h20;
                        6'd28: text_char = 8'h42;
                        6'd29: text_char = 8'h41;
                        6'd30: text_char = 8'h43;
                        6'd31: text_char = 8'h4B;
                        6'd32: text_char = 8'h20;
                        6'd33: text_char = 8'h52;
                        6'd34: text_char = 8'h45;
                        6'd35: text_char = 8'h54;
                        6'd36: text_char = 8'h55;
                        6'd37: text_char = 8'h52;
                        6'd38: text_char = 8'h4E;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd9: begin
                    case (ci)
                        6'd0: text_char = 8'h4B;
                        6'd1: text_char = 8'h45;
                        6'd2: text_char = 8'h59;
                        6'd3: text_char = 8'h50;
                        6'd4: text_char = 8'h41;
                        6'd5: text_char = 8'h44;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd10: begin
                    case (ci)
                        6'd0: text_char = 8'h45;
                        6'd1: text_char = 8'h43;
                        6'd2: text_char = 8'h31;
                        6'd3: text_char = 8'h31;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h43;
                        6'd6: text_char = 8'h4F;
                        6'd7: text_char = 8'h55;
                        6'd8: text_char = 8'h4E;
                        6'd9: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd11: begin
                    case (ci)
                        6'd0: text_char = 8'h50;
                        6'd1: text_char = 8'h53;
                        6'd2: text_char = 8'h32;
                        6'd3: text_char = 8'h20;
                        6'd4: text_char = 8'h43;
                        6'd5: text_char = 8'h4F;
                        6'd6: text_char = 8'h44;
                        6'd7: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd12: begin
                    case (ci)
                        6'd0: text_char = 8'h54;
                        6'd1: text_char = 8'h4F;
                        6'd2: text_char = 8'h55;
                        6'd3: text_char = 8'h43;
                        6'd4: text_char = 8'h48;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd13: begin
                    case (ci)
                        6'd0: text_char = 8'h46;
                        6'd1: text_char = 8'h54;
                        6'd2: text_char = 8'h20;
                        6'd3: text_char = 8'h54;
                        6'd4: text_char = 8'h4F;
                        6'd5: text_char = 8'h55;
                        6'd6: text_char = 8'h43;
                        6'd7: text_char = 8'h48;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd14: begin
                    case (ci)
                        6'd0: text_char = 8'h47;
                        6'd1: text_char = 8'h54;
                        6'd2: text_char = 8'h20;
                        6'd3: text_char = 8'h54;
                        6'd4: text_char = 8'h4F;
                        6'd5: text_char = 8'h55;
                        6'd6: text_char = 8'h43;
                        6'd7: text_char = 8'h48;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd15: begin
                    case (ci)
                        6'd0: text_char = 8'h53;
                        6'd1: text_char = 8'h43;
                        6'd2: text_char = 8'h4F;
                        6'd3: text_char = 8'h52;
                        6'd4: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd16: begin
                    case (ci)
                        6'd0: text_char = 8'h4D;
                        6'd1: text_char = 8'h4F;
                        6'd2: text_char = 8'h56;
                        6'd3: text_char = 8'h45;
                        6'd4: text_char = 8'h53;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd17: begin
                    case (ci)
                        6'd0: text_char = 8'h53;
                        6'd1: text_char = 8'h54;
                        6'd2: text_char = 8'h41;
                        6'd3: text_char = 8'h54;
                        6'd4: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd18: begin
                    case (ci)
                        6'd0: text_char = 8'h52;
                        6'd1: text_char = 8'h45;
                        6'd2: text_char = 8'h41;
                        6'd3: text_char = 8'h44;
                        6'd4: text_char = 8'h59;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd19: begin
                    case (ci)
                        6'd0: text_char = 8'h52;
                        6'd1: text_char = 8'h55;
                        6'd2: text_char = 8'h4E;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd20: begin
                    case (ci)
                        6'd0: text_char = 8'h50;
                        6'd1: text_char = 8'h41;
                        6'd2: text_char = 8'h55;
                        6'd3: text_char = 8'h53;
                        6'd4: text_char = 8'h45;
                        6'd5: text_char = 8'h44;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd21: begin
                    case (ci)
                        6'd0: text_char = 8'h47;
                        6'd1: text_char = 8'h41;
                        6'd2: text_char = 8'h4D;
                        6'd3: text_char = 8'h45;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h4F;
                        6'd6: text_char = 8'h56;
                        6'd7: text_char = 8'h45;
                        6'd8: text_char = 8'h52;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd22: begin
                    case (ci)
                        6'd0: text_char = 8'h57;
                        6'd1: text_char = 8'h49;
                        6'd2: text_char = 8'h4E;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd23: begin
                    case (ci)
                        6'd0: text_char = 8'h4C;
                        6'd1: text_char = 8'h49;
                        6'd2: text_char = 8'h46;
                        6'd3: text_char = 8'h45;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h4C;
                        6'd6: text_char = 8'h4F;
                        6'd7: text_char = 8'h53;
                        6'd8: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd24: begin
                    case (ci)
                        6'd0: text_char = 8'h48;
                        6'd1: text_char = 8'h49;
                        6'd2: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd25: begin
                    case (ci)
                        6'd0: text_char = 8'h43;
                        6'd1: text_char = 8'h4F;
                        6'd2: text_char = 8'h4C;
                        6'd3: text_char = 8'h4F;
                        6'd4: text_char = 8'h52;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd26: begin
                    case (ci)
                        6'd0: text_char = 8'h45;
                        6'd1: text_char = 8'h52;
                        6'd2: text_char = 8'h41;
                        6'd3: text_char = 8'h53;
                        6'd4: text_char = 8'h45;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd27: begin
                    case (ci)
                        6'd0: text_char = 8'h43;
                        6'd1: text_char = 8'h4C;
                        6'd2: text_char = 8'h45;
                        6'd3: text_char = 8'h41;
                        6'd4: text_char = 8'h52;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd28: begin
                    case (ci)
                        6'd0: text_char = 8'h44;
                        6'd1: text_char = 8'h52;
                        6'd2: text_char = 8'h41;
                        6'd3: text_char = 8'h57;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h43;
                        6'd6: text_char = 8'h4F;
                        6'd7: text_char = 8'h55;
                        6'd8: text_char = 8'h4E;
                        6'd9: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd29: begin
                    case (ci)
                        6'd0: text_char = 8'h4C;
                        6'd1: text_char = 8'h45;
                        6'd2: text_char = 8'h46;
                        6'd3: text_char = 8'h54;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h52;
                        6'd6: text_char = 8'h49;
                        6'd7: text_char = 8'h47;
                        6'd8: text_char = 8'h48;
                        6'd9: text_char = 8'h54;
                        6'd10: text_char = 8'h20;
                        6'd11: text_char = 8'h43;
                        6'd12: text_char = 8'h4F;
                        6'd13: text_char = 8'h4C;
                        6'd14: text_char = 8'h4F;
                        6'd15: text_char = 8'h52;
                        6'd16: text_char = 8'h20;
                        6'd17: text_char = 8'h20;
                        6'd18: text_char = 8'h50;
                        6'd19: text_char = 8'h41;
                        6'd20: text_char = 8'h55;
                        6'd21: text_char = 8'h53;
                        6'd22: text_char = 8'h45;
                        6'd23: text_char = 8'h20;
                        6'd24: text_char = 8'h45;
                        6'd25: text_char = 8'h52;
                        6'd26: text_char = 8'h41;
                        6'd27: text_char = 8'h53;
                        6'd28: text_char = 8'h45;
                        6'd29: text_char = 8'h20;
                        6'd30: text_char = 8'h20;
                        6'd31: text_char = 8'h4F;
                        6'd32: text_char = 8'h4B;
                        6'd33: text_char = 8'h20;
                        6'd34: text_char = 8'h43;
                        6'd35: text_char = 8'h4C;
                        6'd36: text_char = 8'h45;
                        6'd37: text_char = 8'h41;
                        6'd38: text_char = 8'h52;
                        6'd39: text_char = 8'h20;
                        6'd40: text_char = 8'h20;
                        6'd41: text_char = 8'h42;
                        6'd42: text_char = 8'h41;
                        6'd43: text_char = 8'h43;
                        6'd44: text_char = 8'h4B;
                        6'd45: text_char = 8'h20;
                        6'd46: text_char = 8'h45;
                        6'd47: text_char = 8'h58;
                        6'd48: text_char = 8'h49;
                        6'd49: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd30: begin
                    case (ci)
                        6'd0: text_char = 8'h41;
                        6'd1: text_char = 8'h52;
                        6'd2: text_char = 8'h52;
                        6'd3: text_char = 8'h4F;
                        6'd4: text_char = 8'h57;
                        6'd5: text_char = 8'h53;
                        6'd6: text_char = 8'h20;
                        6'd7: text_char = 8'h4D;
                        6'd8: text_char = 8'h4F;
                        6'd9: text_char = 8'h56;
                        6'd10: text_char = 8'h45;
                        6'd11: text_char = 8'h20;
                        6'd12: text_char = 8'h20;
                        6'd13: text_char = 8'h4F;
                        6'd14: text_char = 8'h4B;
                        6'd15: text_char = 8'h20;
                        6'd16: text_char = 8'h53;
                        6'd17: text_char = 8'h54;
                        6'd18: text_char = 8'h41;
                        6'd19: text_char = 8'h52;
                        6'd20: text_char = 8'h54;
                        6'd21: text_char = 8'h20;
                        6'd22: text_char = 8'h20;
                        6'd23: text_char = 8'h53;
                        6'd24: text_char = 8'h50;
                        6'd25: text_char = 8'h41;
                        6'd26: text_char = 8'h43;
                        6'd27: text_char = 8'h45;
                        6'd28: text_char = 8'h20;
                        6'd29: text_char = 8'h50;
                        6'd30: text_char = 8'h41;
                        6'd31: text_char = 8'h55;
                        6'd32: text_char = 8'h53;
                        6'd33: text_char = 8'h45;
                        6'd34: text_char = 8'h20;
                        6'd35: text_char = 8'h20;
                        6'd36: text_char = 8'h45;
                        6'd37: text_char = 8'h53;
                        6'd38: text_char = 8'h43;
                        6'd39: text_char = 8'h20;
                        6'd40: text_char = 8'h42;
                        6'd41: text_char = 8'h41;
                        6'd42: text_char = 8'h43;
                        6'd43: text_char = 8'h4B;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd31: begin
                    case (ci)
                        6'd0: text_char = 8'h43;
                        6'd1: text_char = 8'h48;
                        6'd2: text_char = 8'h41;
                        6'd3: text_char = 8'h50;
                        6'd4: text_char = 8'h54;
                        6'd5: text_char = 8'h45;
                        6'd6: text_char = 8'h52;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h31;
                        6'd9: text_char = 8'h35;
                        6'd10: text_char = 8'h20;
                        6'd11: text_char = 8'h41;
                        6'd12: text_char = 8'h43;
                        6'd13: text_char = 8'h43;
                        6'd14: text_char = 8'h45;
                        6'd15: text_char = 8'h50;
                        6'd16: text_char = 8'h54;
                        6'd17: text_char = 8'h41;
                        6'd18: text_char = 8'h4E;
                        6'd19: text_char = 8'h43;
                        6'd20: text_char = 8'h45;
                        6'd21: text_char = 8'h20;
                        6'd22: text_char = 8'h53;
                        6'd23: text_char = 8'h59;
                        6'd24: text_char = 8'h53;
                        6'd25: text_char = 8'h54;
                        6'd26: text_char = 8'h45;
                        6'd27: text_char = 8'h4D;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd32: begin
                    case (ci)
                        6'd0: text_char = 8'h47;
                        6'd1: text_char = 8'h58;
                        6'd2: text_char = 8'h2D;
                        6'd3: text_char = 8'h42;
                        6'd4: text_char = 8'h49;
                        6'd5: text_char = 8'h44;
                        6'd6: text_char = 8'h54;
                        6'd7: text_char = 8'h20;
                        6'd8: text_char = 8'h20;
                        6'd9: text_char = 8'h58;
                        6'd10: text_char = 8'h43;
                        6'd11: text_char = 8'h37;
                        6'd12: text_char = 8'h41;
                        6'd13: text_char = 8'h32;
                        6'd14: text_char = 8'h30;
                        6'd15: text_char = 8'h30;
                        6'd16: text_char = 8'h54;
                        6'd17: text_char = 8'h20;
                        6'd18: text_char = 8'h20;
                        6'd19: text_char = 8'h31;
                        6'd20: text_char = 8'h30;
                        6'd21: text_char = 8'h32;
                        6'd22: text_char = 8'h34;
                        6'd23: text_char = 8'h58;
                        6'd24: text_char = 8'h36;
                        6'd25: text_char = 8'h30;
                        6'd26: text_char = 8'h30;
                        6'd27: text_char = 8'h20;
                        6'd28: text_char = 8'h52;
                        6'd29: text_char = 8'h47;
                        6'd30: text_char = 8'h42;
                        6'd31: text_char = 8'h38;
                        6'd32: text_char = 8'h38;
                        6'd33: text_char = 8'h38;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd33: begin
                    case (ci)
                        6'd0: text_char = 8'h49;
                        6'd1: text_char = 8'h4E;
                        6'd2: text_char = 8'h50;
                        6'd3: text_char = 8'h55;
                        6'd4: text_char = 8'h54;
                        6'd5: text_char = 8'h3A;
                        6'd6: text_char = 8'h20;
                        6'd7: text_char = 8'h4B;
                        6'd8: text_char = 8'h45;
                        6'd9: text_char = 8'h59;
                        6'd10: text_char = 8'h50;
                        6'd11: text_char = 8'h41;
                        6'd12: text_char = 8'h44;
                        6'd13: text_char = 8'h20;
                        6'd14: text_char = 8'h20;
                        6'd15: text_char = 8'h46;
                        6'd16: text_char = 8'h49;
                        6'd17: text_char = 8'h56;
                        6'd18: text_char = 8'h45;
                        6'd19: text_char = 8'h57;
                        6'd20: text_char = 8'h41;
                        6'd21: text_char = 8'h59;
                        6'd22: text_char = 8'h20;
                        6'd23: text_char = 8'h20;
                        6'd24: text_char = 8'h45;
                        6'd25: text_char = 8'h43;
                        6'd26: text_char = 8'h31;
                        6'd27: text_char = 8'h31;
                        6'd28: text_char = 8'h20;
                        6'd29: text_char = 8'h20;
                        6'd30: text_char = 8'h50;
                        6'd31: text_char = 8'h53;
                        6'd32: text_char = 8'h32;
                        6'd33: text_char = 8'h20;
                        6'd34: text_char = 8'h20;
                        6'd35: text_char = 8'h54;
                        6'd36: text_char = 8'h4F;
                        6'd37: text_char = 8'h55;
                        6'd38: text_char = 8'h43;
                        6'd39: text_char = 8'h48;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd34: begin
                    case (ci)
                        6'd0: text_char = 8'h47;
                        6'd1: text_char = 8'h41;
                        6'd2: text_char = 8'h4D;
                        6'd3: text_char = 8'h45;
                        6'd4: text_char = 8'h53;
                        6'd5: text_char = 8'h3A;
                        6'd6: text_char = 8'h20;
                        6'd7: text_char = 8'h54;
                        6'd8: text_char = 8'h52;
                        6'd9: text_char = 8'h45;
                        6'd10: text_char = 8'h41;
                        6'd11: text_char = 8'h53;
                        6'd12: text_char = 8'h55;
                        6'd13: text_char = 8'h52;
                        6'd14: text_char = 8'h45;
                        6'd15: text_char = 8'h20;
                        6'd16: text_char = 8'h20;
                        6'd17: text_char = 8'h53;
                        6'd18: text_char = 8'h4E;
                        6'd19: text_char = 8'h41;
                        6'd20: text_char = 8'h4B;
                        6'd21: text_char = 8'h45;
                        6'd22: text_char = 8'h20;
                        6'd23: text_char = 8'h20;
                        6'd24: text_char = 8'h4D;
                        6'd25: text_char = 8'h41;
                        6'd26: text_char = 8'h5A;
                        6'd27: text_char = 8'h45;
                        6'd28: text_char = 8'h20;
                        6'd29: text_char = 8'h20;
                        6'd30: text_char = 8'h42;
                        6'd31: text_char = 8'h52;
                        6'd32: text_char = 8'h45;
                        6'd33: text_char = 8'h41;
                        6'd34: text_char = 8'h4B;
                        6'd35: text_char = 8'h4F;
                        6'd36: text_char = 8'h55;
                        6'd37: text_char = 8'h54;
                        6'd38: text_char = 8'h20;
                        6'd39: text_char = 8'h20;
                        6'd40: text_char = 8'h50;
                        6'd41: text_char = 8'h41;
                        6'd42: text_char = 8'h49;
                        6'd43: text_char = 8'h4E;
                        6'd44: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd35: begin
                    case (ci)
                        6'd0: text_char = 8'h42;
                        6'd1: text_char = 8'h41;
                        6'd2: text_char = 8'h43;
                        6'd3: text_char = 8'h4B;
                        6'd4: text_char = 8'h20;
                        6'd5: text_char = 8'h52;
                        6'd6: text_char = 8'h45;
                        6'd7: text_char = 8'h54;
                        6'd8: text_char = 8'h55;
                        6'd9: text_char = 8'h52;
                        6'd10: text_char = 8'h4E;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd36: begin
                    case (ci)
                        6'd0: text_char = 8'h4C;
                        6'd1: text_char = 8'h49;
                        6'd2: text_char = 8'h56;
                        6'd3: text_char = 8'h45;
                        6'd4: text_char = 8'h53;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd37: begin
                    case (ci)
                        6'd0: text_char = 8'h45;
                        6'd1: text_char = 8'h58;
                        6'd2: text_char = 8'h54;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd38: begin
                    case (ci)
                        6'd0: text_char = 8'h4E;
                        6'd1: text_char = 8'h4F;
                        6'd2: text_char = 8'h52;
                        6'd3: text_char = 8'h4D;
                        6'd4: text_char = 8'h41;
                        6'd5: text_char = 8'h4C;
                        default: text_char = 8'h20;
                    endcase
                end
                6'd39: begin
                    case (ci)
                        6'd0: text_char = 8'h48;
                        6'd1: text_char = 8'h45;
                        6'd2: text_char = 8'h58;
                        default: text_char = 8'h20;
                    endcase
                end
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            case (nibble)
                4'h0: hex_char = 8'h30; 4'h1: hex_char = 8'h31;
                4'h2: hex_char = 8'h32; 4'h3: hex_char = 8'h33;
                4'h4: hex_char = 8'h34; 4'h5: hex_char = 8'h35;
                4'h6: hex_char = 8'h36; 4'h7: hex_char = 8'h37;
                4'h8: hex_char = 8'h38; 4'h9: hex_char = 8'h39;
                4'hA: hex_char = 8'h41; 4'hB: hex_char = 8'h42;
                4'hC: hex_char = 8'h43; 4'hD: hex_char = 8'h44;
                4'hE: hex_char = 8'h45; default: hex_char = 8'h46;
            endcase
        end
    endfunction

    function char_pixel1;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [7:0] ch;
        reg [10:0] dx; reg [9:0] dy; reg [2:0] col; reg [2:0] row; reg [4:0] rb;
        begin
            char_pixel1=1'b0;
            if ((fx>=ox)&&(fx<ox+11'd8)&&(fy>=oy)&&(fy<oy+10'd8)) begin
                dx=fx-ox; dy=fy-oy; col=dx[2:0]; row=dy[2:0]; rb=glyph_row(ch,row);
                if ((col<3'd5)&&(row<3'd7)) char_pixel1=rb[4-col];
            end
        end
    endfunction

    function char_pixel2;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [7:0] ch;
        reg [10:0] dx; reg [9:0] dy; reg [2:0] col; reg [2:0] row; reg [4:0] rb;
        begin
            char_pixel2=1'b0;
            if ((fx>=ox)&&(fx<ox+11'd16)&&(fy>=oy)&&(fy<oy+10'd16)) begin
                dx=fx-ox; dy=fy-oy; col=dx[3:1]; row=dy[3:1]; rb=glyph_row(ch,row);
                if ((col<3'd5)&&(row<3'd7)) char_pixel2=rb[4-col];
            end
        end
    endfunction

    function char_pixel4;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [7:0] ch;
        reg [10:0] dx; reg [9:0] dy; reg [2:0] col; reg [2:0] row; reg [4:0] rb;
        begin
            char_pixel4=1'b0;
            if ((fx>=ox)&&(fx<ox+11'd32)&&(fy>=oy)&&(fy<oy+10'd32)) begin
                dx=fx-ox; dy=fy-oy; col=dx[4:2]; row=dy[4:2]; rb=glyph_row(ch,row);
                if ((col<3'd5)&&(row<3'd7)) char_pixel4=rb[4-col];
            end
        end
    endfunction

    function text_pixel1;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [5:0] tid;
        reg [10:0] dx; reg [5:0] ci; reg [7:0] ch;
        begin
            text_pixel1=1'b0;
            if ((fx>=ox)&&(fx<ox+11'd512)&&(fy>=oy)&&(fy<oy+10'd8)) begin
                dx=fx-ox; ci=dx[8:3]; ch=text_char(tid,ci);
                text_pixel1=char_pixel1(fx,fy,ox+{ci,3'b000},oy,ch);
            end
        end
    endfunction

    function text_pixel2;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [5:0] tid;
        reg [10:0] dx; reg [5:0] ci; reg [7:0] ch;
        begin
            text_pixel2=1'b0;
            if ((fx>=ox)&&(fy>=oy)&&(fy<oy+10'd16)) begin
                dx=fx-ox; ci=dx[9:4]; ch=text_char(tid,ci);
                text_pixel2=char_pixel2(fx,fy,ox+{ci,4'b0000},oy,ch);
            end
        end
    endfunction

    function text_pixel4;
        input [10:0] fx; input [9:0] fy; input [10:0] ox; input [9:0] oy; input [5:0] tid;
        reg [10:0] dx; reg [5:0] ci; reg [7:0] ch;
        begin
            text_pixel4=1'b0;
            if ((fx>=ox)&&(fy>=oy)&&(fy<oy+10'd32)) begin
                dx=fx-ox; ci=dx[10:5]; ch=text_char(tid,ci);
                text_pixel4=char_pixel4(fx,fy,ox+{ci,5'b00000},oy,ch);
            end
        end
    endfunction

    integer idx; integer top_y; integer bot_y;
    wire horizontal_crosshair=((x+11'd10)>=pointer_x)&&(x<=pointer_x+11'd10)&&(y==pointer_y);
    wire vertical_crosshair=((y+10'd10)>=pointer_y)&&(y<=pointer_y+10'd10)&&(x==pointer_x);
    wire crosshair=pointer_visible&&(horizontal_crosshair||vertical_crosshair);

    wire game_hex0=char_pixel2(x,y,11'd400,10'd4,hex_char(game_score[15:12]));
    wire game_hex1=char_pixel2(x,y,11'd416,10'd4,hex_char(game_score[11:8]));
    wire game_hex2=char_pixel2(x,y,11'd432,10'd4,hex_char(game_score[7:4]));
    wire game_hex3=char_pixel2(x,y,11'd448,10'd4,hex_char(game_score[3:0]));
    wire keypad_hex=char_pixel4(x,y,11'd820,10'd68,hex_char(keypad_code));
    wire ec_hex_hi=char_pixel4(x,y,11'd788,10'd158,hex_char({3'b000,ec_count[4]}));
    wire ec_hex_lo=char_pixel4(x,y,11'd820,10'd158,hex_char(ec_count[3:0]));
    wire ps2_hex_hi=char_pixel4(x,y,11'd788,10'd248,hex_char(keyboard_code[7:4]));
    wire ps2_hex_lo=char_pixel4(x,y,11'd820,10'd248,hex_char(keyboard_code[3:0]));

    always @(*) begin
        if (!active_video) begin
            rgb=24'h000000;
        end else if (ui_state==3'd0) begin
            rgb=24'h17212B;
            for (idx=0;idx<7;idx=idx+1) begin
                top_y=40+idx*76; bot_y=top_y+58;
                if ((x>=140)&&(x<884)&&(y>=top_y)&&(y<bot_y))
                    rgb=(menu_sel==idx)?C_YELLOW:(idx[0]?C_BLUE:C_GREEN);
            end
            if (text_pixel2(x,y,11'd320,10'd12,T_HOME_TITLE)) rgb=C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd53,T_MENU_INPUT)) rgb=(menu_sel==0)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd129,T_MENU_TREASURE)) rgb=(menu_sel==1)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd205,T_MENU_SNAKE)) rgb=(menu_sel==2)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd281,T_MENU_MAZE)) rgb=(menu_sel==3)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd357,T_MENU_BREAKOUT)) rgb=(menu_sel==4)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd433,T_MENU_PAINT)) rgb=(menu_sel==5)?C_BLACK:C_WHITE;
            if (text_pixel4(x,y,11'd250,10'd509,T_MENU_INFO)) rgb=(menu_sel==6)?C_BLACK:C_WHITE;
            if (text_pixel1(x,y,11'd332,10'd582,T_HOME_HELP)) rgb=C_WHITE;
            if (crosshair) rgb=C_WHITE;
        end else if (ui_state==3'd1) begin
            rgb=24'h10233D;
            if (text_pixel2(x,y,11'd392,10'd8,T_MENU_INPUT)) rgb=C_WHITE;
            if ((y>=60)&&(y<110)&&(x<(keypad_code*64+64))) rgb=C_YELLOW;
            if ((y>=150)&&(y<200)&&(x<(ec_count*28+28))) rgb=C_GREEN;
            if ((y>=240)&&(y<290)&&(x<({3'b000,keyboard_code[6:0]}*6+6))) rgb=keyboard_extended?C_PURPLE:C_CYAN;
            if ((y>=330)&&(y<380)&&(x>=60)&&(x<300)) rgb=ft_flag?C_GREEN:C_BLUE;
            if ((x==512)||(y==300)) rgb=24'h667788;
            if (keypad_valid_latched&&(x>=900)&&(y<80)) rgb=C_YELLOW;
            if (text_pixel2(x,y,11'd60,10'd38,T_KEYPAD)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd60,10'd128,T_EC11)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd60,10'd218,T_PS2)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd60,10'd308,T_TOUCH)) rgb=C_WHITE;
            if (ft_flag) begin if (text_pixel2(x,y,11'd320,10'd348,T_FT_TOUCH)) rgb=C_WHITE; end
            else begin if (text_pixel2(x,y,11'd320,10'd348,T_GT_TOUCH)) rgb=C_WHITE; end
            if (keyboard_extended) begin if (text_pixel2(x,y,11'd870,10'd250,T_EXT)) rgb=C_WHITE; end
            else begin if (text_pixel2(x,y,11'd870,10'd250,T_NORMAL)) rgb=C_WHITE; end
            if (keypad_hex||ec_hex_hi||ec_hex_lo||ps2_hex_hi||ps2_hex_lo) rgb=C_WHITE;
            if (text_pixel1(x,y,11'd350,10'd582,T_BACK_RETURN)) rgb=C_WHITE;
            if (crosshair) rgb=C_WHITE;
        end else if ((ui_state>=3'd2)&&(ui_state<=3'd6)) begin
            rgb=game_pixel_on?game_pixel_rgb:24'h101820;
            if (ui_state!=3'd6) begin
                if ((y>=4)&&(y<12)&&(x<({5'd0,game_score[5:0]}<<3))) rgb=C_YELLOW;
                if ((y>=48)&&(y<56)&&(x<({7'd0,game_state}<<5))) rgb=C_WHITE;
                case (ui_state)
                    3'd2: if (text_pixel2(x,y,11'd20,10'd4,T_MENU_TREASURE)) rgb=C_WHITE;
                    3'd3: if (text_pixel2(x,y,11'd20,10'd4,T_MENU_SNAKE)) rgb=C_WHITE;
                    3'd4: if (text_pixel2(x,y,11'd20,10'd4,T_MENU_MAZE)) rgb=C_WHITE;
                    3'd5: if (text_pixel2(x,y,11'd20,10'd4,T_MENU_BREAKOUT)) rgb=C_WHITE;
                    default: ;
                endcase
                if (ui_state==3'd4) begin if (text_pixel2(x,y,11'd300,10'd4,T_MOVES)) rgb=C_WHITE; end
                else begin if (text_pixel2(x,y,11'd300,10'd4,T_SCORE)) rgb=C_WHITE; end
                if (game_hex0||game_hex1||game_hex2||game_hex3) rgb=C_WHITE;
                if (text_pixel2(x,y,11'd500,10'd4,T_STATE)) rgb=C_WHITE;
                case (game_state)
                    4'd0: if (text_pixel2(x,y,11'd590,10'd4,T_READY)) rgb=C_WHITE;
                    4'd1: if (text_pixel2(x,y,11'd590,10'd4,T_RUN)) rgb=C_WHITE;
                    4'd2: if (text_pixel2(x,y,11'd590,10'd4,T_PAUSED)) rgb=C_WHITE;
                    4'd3: begin
                        if (ui_state==3'd2) begin if (text_pixel2(x,y,11'd590,10'd4,T_HIT)) rgb=C_WHITE; end
                        else if (ui_state==3'd5) begin if (text_pixel2(x,y,11'd590,10'd4,T_LIFE_LOST)) rgb=C_WHITE; end
                    end
                    4'd4: begin
                        if ((ui_state==3'd4)||(ui_state==3'd5)) begin if (text_pixel2(x,y,11'd590,10'd4,T_WIN)) rgb=C_WHITE; end
                        else begin if (text_pixel2(x,y,11'd590,10'd4,T_GAME_OVER)) rgb=C_WHITE; end
                    end
                    4'd5: if (text_pixel2(x,y,11'd590,10'd4,T_GAME_OVER)) rgb=C_WHITE;
                    default: ;
                endcase
                if ((ui_state==3'd5)&&text_pixel2(x,y,11'd820,10'd4,T_LIVES)) rgb=C_WHITE;
                if (text_pixel1(x,y,11'd330,10'd590,T_GAME_HELP)) rgb=C_WHITE;
                if ((game_state==4'd0)&&text_pixel4(x,y,11'd416,10'd280,T_READY)) rgb=C_BLACK;
                else if ((game_state==4'd2)&&text_pixel4(x,y,11'd400,10'd280,T_PAUSED)) rgb=C_BLACK;
                else if ((game_state==4'd4)&&((ui_state==3'd4)||(ui_state==3'd5))&&text_pixel4(x,y,11'd448,10'd280,T_WIN)) rgb=C_BLACK;
                else if ((game_state==4'd3)&&(ui_state==3'd5)&&text_pixel2(x,y,11'd430,10'd300,T_LIFE_LOST)) rgb=C_BLACK;
                else if ((((game_state==4'd4)&&((ui_state==3'd2)||(ui_state==3'd3)))||((game_state==4'd5)&&(ui_state==3'd5)))&&text_pixel4(x,y,11'd352,10'd280,T_GAME_OVER)) rgb=C_WHITE;
            end else begin
                if (text_pixel2(x,y,11'd400,10'd4,T_MENU_PAINT)) rgb=C_WHITE;
                if (text_pixel2(x,y,11'd20,10'd80,T_COLOR)) rgb=C_WHITE;
                if (text_pixel2(x,y,11'd700,10'd40,T_ERASE)) rgb=C_WHITE;
                if (text_pixel2(x,y,11'd866,10'd40,T_CLEAR)) rgb=C_WHITE;
                if (text_pixel1(x,y,11'd360,10'd82,T_DRAW_COUNT)) rgb=C_WHITE;
                if (char_pixel1(x,y,11'd456,10'd82,hex_char(game_score[15:12]))||char_pixel1(x,y,11'd464,10'd82,hex_char(game_score[11:8]))||char_pixel1(x,y,11'd472,10'd82,hex_char(game_score[7:4]))||char_pixel1(x,y,11'd480,10'd82,hex_char(game_score[3:0]))) rgb=C_WHITE;
                if (text_pixel1(x,y,11'd520,10'd82,T_PAINT_HELP)) rgb=C_WHITE;
            end
            if (crosshair) rgb=C_WHITE;
        end else begin
            rgb=C_GRAY;
            if ((x<8)||(x>1015)||(y<8)||(y>591)) rgb=C_WHITE;
            if ((x>=128)&&(x<896)&&(y>=128)&&(y<472)) rgb=24'h34434D;
            if (text_pixel2(x,y,11'd290,10'd92,T_INFO_TITLE)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd190,10'd160,T_INFO_PLATFORM)) rgb=C_YELLOW;
            if (text_pixel2(x,y,11'd170,10'd220,T_INFO_INPUT)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd150,10'd280,T_INFO_GAMES)) rgb=C_WHITE;
            if (text_pixel2(x,y,11'd400,10'd360,T_BACK_RETURN)) rgb=C_CYAN;
            if (text_pixel1(x,y,11'd332,10'd582,T_HOME_HELP)) rgb=C_WHITE;
            if (crosshair) rgb=C_WHITE;
        end
    end
endmodule
