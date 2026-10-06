`timescale 1ns/1ps

module ec11_compat #(
    parameter integer CLK_HZ     = 50_000_000,
    parameter integer LOCKOUT_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ec_a,
    input  wire ec_b,
    output reg  step_pulse,
    output reg  step_dir
);

    // 50 MHz下连续稳定8个周期，约160 ns。
    // 接触抖动由完整AB相序列判断消除，不使用毫秒级滤波。
    localparam integer FILTER_CYCLES = 8;

    // 两级同步
    (* ASYNC_REG = "TRUE" *) reg [1:0] a_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] b_sync;

    wire [1:0] sync_ab = {a_sync[1], b_sync[1]};

    // 稳定状态滤波
    reg [1:0]  candidate_ab;
    reg [1:0]  stable_ab;
    reg [31:0] stable_count;

    // 累计四分之一相位；完整一格包含4个有效相位变化
    reg signed [3:0] phase_accum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_sync <= 2'b11;
            b_sync <= 2'b11;
        end else begin
            a_sync <= {a_sync[0], ec_a};
            b_sync <= {b_sync[0], ec_b};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate_ab <= 2'b11;
            stable_ab    <= 2'b11;
            stable_count <= 32'd0;
            phase_accum  <= 4'sd0;
            step_pulse   <= 1'b0;
            step_dir     <= 1'b0;
        end else begin
            step_pulse <= 1'b0;

            // 输入状态改变，重新开始稳定计时
            if (sync_ab != candidate_ab) begin
                candidate_ab <= sync_ab;
                stable_count <= 32'd0;

            end else if (candidate_ab != stable_ab) begin
                if (stable_count >= FILTER_CYCLES - 1) begin
                    stable_count <= 32'd0;
                    stable_ab    <= candidate_ab;

                    case ({stable_ab, candidate_ab})

                        // 一个方向：
                        // 11 -> 10 -> 00 -> 01 -> 11
                        4'b1110,
                        4'b1000,
                        4'b0001,
                        4'b0111: begin
                            if (candidate_ab == 2'b11) begin
                                if (phase_accum == 4'sd3) begin
                                    step_pulse <= 1'b1;
                                    step_dir   <= 1'b1;
                                end
                                phase_accum <= 4'sd0;
                            end else begin
                                phase_accum <= phase_accum + 4'sd1;
                            end
                        end

                        // 另一个方向：
                        // 11 -> 01 -> 00 -> 10 -> 11
                        4'b1101,
                        4'b0100,
                        4'b0010,
                        4'b1011: begin
                            if (candidate_ab == 2'b11) begin
                                if (phase_accum == -4'sd3) begin
                                    step_pulse <= 1'b1;
                                    step_dir   <= 1'b0;
                                end
                                phase_accum <= 4'sd0;
                            end else begin
                                phase_accum <= phase_accum - 4'sd1;
                            end
                        end

                        // 跳过状态或非法跳变：放弃本次不完整动作
                        default: begin
                            phase_accum <= 4'sd0;
                        end
                    endcase
                end else begin
                    stable_count <= stable_count + 32'd1;
                end
            end else begin
                stable_count <= 32'd0;
            end
        end
    end

endmodule
