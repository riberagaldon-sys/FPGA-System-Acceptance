`timescale 1ns/1ps

// Chapter 13: touch/mouse paint board for the verified 1024 x 600 panel.
//
// The tutorial's 200 x 120, 4-bit logical canvas is enlarged 4 x 4 to an
// 800 x 480 visible canvas.  It is centred horizontally at X=112..911 and
// placed at Y=100..579, leaving a 100-pixel toolbar above it.
module paint_board(
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

    localparam integer CANVAS_W      = 200;
    localparam integer CANVAS_H      = 120;
    localparam integer CANVAS_SIZE   = 24000;
    localparam integer CANVAS_LEFT   = 112;
    localparam integer CANVAS_TOP    = 100;
    localparam integer CANVAS_RIGHT  = 912;
    localparam integer CANVAS_BOTTOM = 580;

    localparam integer PALETTE_X0    = 20;
    localparam integer PALETTE_Y0    = 20;
    localparam integer PALETTE_STEP  = 62;
    localparam integer PALETTE_W     = 54;
    localparam integer PALETTE_H     = 56;
    localparam integer ERASE_X0      = 680;
    localparam integer ERASE_X1      = 815;
    localparam integer CLEAR_X0      = 840;
    localparam integer CLEAR_X1      = 1000;

    localparam [2:0]
        ST_IDLE       = 3'd0,
        ST_DRAW       = 3'd1,
        ST_ERASE      = 3'd2,
        ST_CLEAR      = 3'd3,
        ST_CLEAR_DONE = 3'd4;

    localparam [23:0]
        C_BG       = 24'h17212B,
        C_TOOLBAR  = 24'h22303D,
        C_BORDER   = 24'hC7D1D9,
        C_YELLOW   = 24'hE3B341,
        C_ERASE    = 24'hD66A5E,
        C_CLEAR    = 24'hE8874A,
        C_INACTIVE = 24'h5E6870;

    // Simple dual-port RAM style: one synchronous write port and one
    // synchronous display-read port.  Vivado can map the 96,000-bit array to
    // block RAM.  The read address looks one physical pixel ahead to match
    // the existing one-cycle RGB output register in the verified LCD top.
    (* ram_style = "block" *) reg [3:0] canvas_mem [0:CANVAS_SIZE-1];
    reg [3:0] canvas_rdata;

    reg [2:0]  state_live;
    reg [3:0]  selected_color;
    reg        erase_mode;
    reg [14:0] clear_addr;
    reg [15:0] draw_count;
    reg        game_enable_d;
    reg        pointer_down_d;
    reg        pointer_armed;
    reg        stroke_active;
    reg [7:0]  stroke_x;
    reg [6:0]  stroke_y;
    reg [7:0]  stroke_target_x;
    reg [6:0]  stroke_target_y;
    reg [3:0]  erase_brush_phase;
    reg [14:0] last_draw_addr;
    reg        last_draw_valid;

    integer palette_i;
    integer draw_i;

    wire pointer_press = pointer_down && !pointer_down_d;
    wire pointer_in_canvas =
        (pointer_x >= CANVAS_LEFT) && (pointer_x < CANVAS_RIGHT) &&
        (pointer_y >= CANVAS_TOP)  && (pointer_y < CANVAS_BOTTOM);

    wire [7:0] pointer_canvas_x =
        (pointer_x - CANVAS_LEFT) >> 2;
    wire [6:0] pointer_canvas_y =
        (pointer_y - CANVAS_TOP) >> 2;
    wire pointer_in_erase =
        pointer_armed && pointer_press && (pointer_x >= ERASE_X0) &&
        (pointer_x < ERASE_X1) &&
        (pointer_y >= PALETTE_Y0) &&
        (pointer_y < PALETTE_Y0 + PALETTE_H);

    wire pointer_in_clear =
        pointer_armed && pointer_press && (pointer_x >= CLEAR_X0) &&
        (pointer_x < CLEAR_X1) &&
        (pointer_y >= PALETTE_Y0) &&
        (pointer_y < PALETTE_Y0 + PALETTE_H);

    wire pointer_canvas_request =
        game_enable && (state_live != ST_CLEAR) &&
        (state_live != ST_CLEAR_DONE) &&
        pointer_armed && pointer_down && pointer_in_canvas;

    wire [14:0] stroke_addr = stroke_y * CANVAS_W + stroke_x;

    // Erasing uses a 3x3 logical-pixel brush.  The nine cells are written
    // over nine clocks through the same single RAM write port, after which
    // the stroke advances one interpolated cell toward its latest target.
    // At 51.2 MHz this remains far faster than incoming touch coordinates.
    reg [7:0] erase_brush_x;
    reg [6:0] erase_brush_y;

    always @(*) begin
        erase_brush_x = stroke_x;
        erase_brush_y = stroke_y;

        case (erase_brush_phase)
            4'd1: if (stroke_x > 8'd0)
                      erase_brush_x = stroke_x - 8'd1;
            4'd2: if (stroke_x < CANVAS_W - 1)
                      erase_brush_x = stroke_x + 8'd1;
            4'd3: if (stroke_y > 7'd0)
                      erase_brush_y = stroke_y - 7'd1;
            4'd4: if (stroke_y < CANVAS_H - 1)
                      erase_brush_y = stroke_y + 7'd1;
            4'd5: begin
                if (stroke_x > 8'd0)
                    erase_brush_x = stroke_x - 8'd1;
                if (stroke_y > 7'd0)
                    erase_brush_y = stroke_y - 7'd1;
            end
            4'd6: begin
                if (stroke_x < CANVAS_W - 1)
                    erase_brush_x = stroke_x + 8'd1;
                if (stroke_y > 7'd0)
                    erase_brush_y = stroke_y - 7'd1;
            end
            4'd7: begin
                if (stroke_x > 8'd0)
                    erase_brush_x = stroke_x - 8'd1;
                if (stroke_y < CANVAS_H - 1)
                    erase_brush_y = stroke_y + 7'd1;
            end
            4'd8: begin
                if (stroke_x < CANVAS_W - 1)
                    erase_brush_x = stroke_x + 8'd1;
                if (stroke_y < CANVAS_H - 1)
                    erase_brush_y = stroke_y + 7'd1;
            end
            default: begin
                erase_brush_x = stroke_x;
                erase_brush_y = stroke_y;
            end
        endcase
    end

    wire [14:0] erase_brush_addr =
        erase_brush_y * CANVAS_W + erase_brush_x;
    wire stroke_write =
        game_enable && stroke_active &&
        (state_live != ST_CLEAR) && (state_live != ST_CLEAR_DONE);

    // Touch swipes become unified direction events one clock after release.
    // Keeping the previous down level in this guard prevents a drawing
    // gesture from changing the selected palette color or erase mode.
    wire pointer_gesture_guard = pointer_down || pointer_down_d;

    wire ram_we = (state_live == ST_CLEAR) || stroke_write;
    wire [14:0] ram_waddr =
        (state_live == ST_CLEAR) ? clear_addr :
        (erase_mode ? erase_brush_addr : stroke_addr);
    wire [3:0] ram_wdata =
        (state_live == ST_CLEAR) ? 4'h0 :
        (erase_mode ? 4'h0 : selected_color);

    wire [10:0] read_pixel_x = pixel_x + 11'd1;
    wire read_pixel_in_canvas =
        (read_pixel_x >= CANVAS_LEFT) &&
        (read_pixel_x < CANVAS_RIGHT) &&
        (pixel_y >= CANVAS_TOP) && (pixel_y < CANVAS_BOTTOM);
    wire [7:0] read_canvas_x =
        (read_pixel_x - CANVAS_LEFT) >> 2;
    wire [6:0] read_canvas_y =
        (pixel_y - CANVAS_TOP) >> 2;
    wire [14:0] canvas_raddr = read_pixel_in_canvas ?
        (read_canvas_y * CANVAS_W + read_canvas_x) : 15'd0;

    always @(posedge clk) begin
        if (ram_we)
            canvas_mem[ram_waddr] <= ram_wdata;
        canvas_rdata <= canvas_mem[canvas_raddr];
    end

    assign pixel_on     = 1'b1;
    assign score        = draw_count;
    assign exit_request = game_enable && event_back;

    // bit2: clearing, bit1: erase mode, bit0: pointer drawing
    assign game_state = {
        1'b0,
        (state_live == ST_CLEAR),
        erase_mode,
        stroke_write
    };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_live      <= ST_IDLE;
            selected_color  <= 4'h2;
            erase_mode      <= 1'b0;
            clear_addr      <= 15'd0;
            draw_count      <= 16'd0;
            game_enable_d   <= 1'b0;
            pointer_down_d  <= 1'b0;
            pointer_armed   <= 1'b0;
            stroke_active   <= 1'b0;
            stroke_x        <= 8'd0;
            stroke_y        <= 7'd0;
            stroke_target_x <= 8'd0;
            stroke_target_y <= 7'd0;
            erase_brush_phase <= 4'd0;
            last_draw_addr  <= 15'd0;
            last_draw_valid <= 1'b0;
        end else begin
            game_enable_d  <= game_enable;
            pointer_down_d <= pointer_down;

            // A touch used to enter the menu page must be released before it
            // can draw/select a tool on the new page.
            if (!pointer_down)
                pointer_armed <= 1'b1;

            if (!game_enable) begin
                state_live      <= ST_IDLE;
                selected_color  <= 4'h2;
                erase_mode      <= 1'b0;
                clear_addr      <= 15'd0;
                draw_count      <= 16'd0;
                last_draw_addr  <= 15'd0;
                last_draw_valid <= 1'b0;
                pointer_armed   <= 1'b0;
                stroke_active   <= 1'b0;
                stroke_x        <= 8'd0;
                stroke_y        <= 7'd0;
                stroke_target_x <= 8'd0;
                stroke_target_y <= 7'd0;
                erase_brush_phase <= 4'd0;
            end else if (game_enable && !game_enable_d) begin
                // Each entry starts from a deterministic black canvas.
                state_live      <= ST_CLEAR;
                clear_addr      <= 15'd0;
                draw_count      <= 16'd0;
                last_draw_valid <= 1'b0;
                pointer_armed   <= 1'b0;
                stroke_active   <= 1'b0;
                erase_brush_phase <= 4'd0;
            end else if (state_live == ST_CLEAR) begin
                draw_count <= 16'd0;
                if (clear_addr == CANVAS_SIZE - 1) begin
                    state_live <= ST_CLEAR_DONE;
                    clear_addr <= 15'd0;
                end else begin
                    clear_addr <= clear_addr + 15'd1;
                end
            end else if (state_live == ST_CLEAR_DONE) begin
                state_live <= ST_IDLE;
            end else if ((event_ok && !pointer_gesture_guard) ||
                         pointer_in_clear) begin
                state_live      <= ST_CLEAR;
                clear_addr      <= 15'd0;
                draw_count      <= 16'd0;
                last_draw_valid <= 1'b0;
                stroke_active   <= 1'b0;
                erase_brush_phase <= 4'd0;
            end else begin
                if (event_pause || pointer_in_erase)
                    erase_mode <= ~erase_mode;
                else if (event_up && !pointer_gesture_guard)
                    erase_mode <= 1'b0;
                else if (event_down && !pointer_gesture_guard)
                    erase_mode <= 1'b1;

                if (event_left && !pointer_gesture_guard) begin
                    erase_mode <= 1'b0;
                    if (selected_color == 4'd0)
                        selected_color <= 4'd9;
                    else
                        selected_color <= selected_color - 4'd1;
                end else if (event_right && !pointer_gesture_guard) begin
                    erase_mode <= 1'b0;
                    if (selected_color == 4'd9)
                        selected_color <= 4'd0;
                    else
                        selected_color <= selected_color + 4'd1;
                end

                if (pointer_armed && pointer_press &&
                    (pointer_y >= PALETTE_Y0) &&
                    (pointer_y < PALETTE_Y0 + PALETTE_H)) begin
                    for (palette_i = 0; palette_i < 10;
                         palette_i = palette_i + 1) begin
                        if ((pointer_x >= PALETTE_X0 +
                             palette_i * PALETTE_STEP) &&
                            (pointer_x < PALETTE_X0 +
                             palette_i * PALETTE_STEP + PALETTE_W)) begin
                            selected_color <= palette_i[3:0];
                            erase_mode     <= 1'b0;
                        end
                    end
                end

                // Start a stroke from the first logical touch cell.
                if (!stroke_active && pointer_canvas_request) begin
                    stroke_active   <= 1'b1;
                    stroke_x        <= pointer_canvas_x;
                    stroke_y        <= pointer_canvas_y;
                    stroke_target_x <= pointer_canvas_x;
                    stroke_target_y <= pointer_canvas_y;
                    erase_brush_phase <= 4'd0;
                    state_live      <= erase_mode ? ST_ERASE : ST_DRAW;
                    last_draw_valid <= 1'b0;
                end else if (stroke_active) begin
                    state_live <= erase_mode ? ST_ERASE : ST_DRAW;

                    // Follow the most recent touch coordinate.  At 51.2 MHz
                    // all omitted logical cells are filled long before the
                    // touch controller supplies its next coordinate.
                    if (pointer_down && pointer_in_canvas) begin
                        stroke_target_x <= pointer_canvas_x;
                        stroke_target_y <= pointer_canvas_y;
                    end

                    if (erase_mode) begin
                        last_draw_valid <= 1'b0;

                        // Complete all nine brush cells before advancing the
                        // interpolated centre point or ending the stroke.
                        if (erase_brush_phase == 4'd8) begin
                            erase_brush_phase <= 4'd0;

                            if (stroke_x < stroke_target_x)
                                stroke_x <= stroke_x + 8'd1;
                            else if (stroke_x > stroke_target_x)
                                stroke_x <= stroke_x - 8'd1;

                            if (stroke_y < stroke_target_y)
                                stroke_y <= stroke_y + 7'd1;
                            else if (stroke_y > stroke_target_y)
                                stroke_y <= stroke_y - 7'd1;

                            if (!pointer_down &&
                                (stroke_x == stroke_target_x) &&
                                (stroke_y == stroke_target_y)) begin
                                stroke_active <= 1'b0;
                                state_live    <= ST_IDLE;
                            end
                        end else begin
                            erase_brush_phase <= erase_brush_phase + 4'd1;
                        end
                    end else begin
                        erase_brush_phase <= 4'd0;

                        if (stroke_x < stroke_target_x)
                            stroke_x <= stroke_x + 8'd1;
                        else if (stroke_x > stroke_target_x)
                            stroke_x <= stroke_x - 8'd1;

                        if (stroke_y < stroke_target_y)
                            stroke_y <= stroke_y + 7'd1;
                        else if (stroke_y > stroke_target_y)
                            stroke_y <= stroke_y - 7'd1;

                        if (!last_draw_valid ||
                            (stroke_addr != last_draw_addr))
                            draw_count <= draw_count + 16'd1;

                        last_draw_addr  <= stroke_addr;
                        last_draw_valid <= 1'b1;

                        if (!pointer_down &&
                            (stroke_x == stroke_target_x) &&
                            (stroke_y == stroke_target_y)) begin
                            stroke_active   <= 1'b0;
                            state_live      <= ST_IDLE;
                            last_draw_valid <= 1'b0;
                        end
                    end
                end else begin
                    state_live <= ST_IDLE;
                    erase_brush_phase <= 4'd0;
                    if (!pointer_down)
                        last_draw_valid <= 1'b0;
                end
            end
        end
    end

    function [23:0] palette_rgb;
        input [3:0] color_index;
        begin
            case (color_index)
                4'h0: palette_rgb = 24'h000000;
                4'h1: palette_rgb = 24'hFFFFFF;
                4'h2: palette_rgb = 24'hFF3030;
                4'h3: palette_rgb = 24'h30D060;
                4'h4: palette_rgb = 24'h3060FF;
                4'h5: palette_rgb = 24'hFFE040;
                4'h6: palette_rgb = 24'h30E0E0;
                4'h7: palette_rgb = 24'hF040E0;
                4'h8: palette_rgb = 24'h808890;
                4'h9: palette_rgb = 24'hFF9030;
                4'hA: palette_rgb = 24'h805020;
                4'hB: palette_rgb = 24'h80FF40;
                4'hC: palette_rgb = 24'h4080A0;
                4'hD: palette_rgb = 24'hA060E0;
                4'hE: palette_rgb = 24'hFFD0A0;
                default: palette_rgb = 24'hC0C0C0;
            endcase
        end
    endfunction

    wire pixel_in_canvas =
        (pixel_x >= CANVAS_LEFT) && (pixel_x < CANVAS_RIGHT) &&
        (pixel_y >= CANVAS_TOP)  && (pixel_y < CANVAS_BOTTOM);

    always @(*) begin
        pixel_rgb = C_BG;

        if (pixel_y < CANVAS_TOP)
            pixel_rgb = C_TOOLBAR;

        // Four-pixel border around the 800 x 480 canvas.
        if ((pixel_x >= CANVAS_LEFT - 4) &&
            (pixel_x < CANVAS_RIGHT + 4) &&
            (pixel_y >= CANVAS_TOP - 4) &&
            (pixel_y < CANVAS_BOTTOM + 4))
            pixel_rgb = C_BORDER;

        if (pixel_in_canvas)
            pixel_rgb = palette_rgb(canvas_rdata);

        // Ten directly selectable palette swatches.
        for (draw_i = 0; draw_i < 10; draw_i = draw_i + 1) begin
            if ((pixel_x >= PALETTE_X0 + draw_i * PALETTE_STEP) &&
                (pixel_x < PALETTE_X0 + draw_i * PALETTE_STEP + PALETTE_W) &&
                (pixel_y >= PALETTE_Y0) &&
                (pixel_y < PALETTE_Y0 + PALETTE_H)) begin
                if ((selected_color == draw_i[3:0]) && !erase_mode &&
                    ((pixel_x < PALETTE_X0 + draw_i * PALETTE_STEP + 4) ||
                     (pixel_x >= PALETTE_X0 + draw_i * PALETTE_STEP +
                                  PALETTE_W - 4) ||
                     (pixel_y < PALETTE_Y0 + 4) ||
                     (pixel_y >= PALETTE_Y0 + PALETTE_H - 4)))
                    pixel_rgb = C_YELLOW;
                else
                    pixel_rgb = palette_rgb(draw_i[3:0]);
            end
        end

        // ERASE button: red when active, gray when inactive.
        if ((pixel_x >= ERASE_X0) && (pixel_x < ERASE_X1) &&
            (pixel_y >= PALETTE_Y0) &&
            (pixel_y < PALETTE_Y0 + PALETTE_H)) begin
            if ((pixel_x < ERASE_X0 + 5) || (pixel_x >= ERASE_X1 - 5) ||
                (pixel_y < PALETTE_Y0 + 5) ||
                (pixel_y >= PALETTE_Y0 + PALETTE_H - 5))
                pixel_rgb = erase_mode ? C_YELLOW : C_INACTIVE;
            else
                pixel_rgb = erase_mode ? C_ERASE : 24'h72443F;
        end

        // CLEAR button.
        if ((pixel_x >= CLEAR_X0) && (pixel_x < CLEAR_X1) &&
            (pixel_y >= PALETTE_Y0) &&
            (pixel_y < PALETTE_Y0 + PALETTE_H)) begin
            if ((pixel_x < CLEAR_X0 + 5) || (pixel_x >= CLEAR_X1 - 5) ||
                (pixel_y < PALETTE_Y0 + 5) ||
                (pixel_y >= PALETTE_Y0 + PALETTE_H - 5))
                pixel_rgb = C_YELLOW;
            else
                pixel_rgb = C_CLEAR;
        end

        // Short progress line while the block-RAM canvas is being cleared.
        if ((state_live == ST_CLEAR) &&
            (pixel_y >= 10'd84) && (pixel_y < 10'd92) &&
            (pixel_x < ((clear_addr >> 5) +
                        (clear_addr >> 7) +
                        (clear_addr >> 8))))
            pixel_rgb = C_YELLOW;
    end

endmodule
