`timescale 1ns/1ps

// 第16章：模块回归与系统综合验收——图16-1、图16-2专用自检。
// 工程：chapter15_verification_acceptance_200t.xpr
// Simulation Sources添加本文件，Simulation Top设为tb_chapter16_all。
// Tcl：run 3 ms。成功时打印CH16 PASS；保持仿真窗口，无$finish/$stop。
// 使用工程原有frame_snapshot_bus、i2c_dri，不复制或修改设计模块。
// 像素域时钟标称51.2MHz（1ps仿真精度）；I2C参数CLK_FREQ=51200000、I2C_FREQ=250000、WIDTH=8。
// 快照WIDTH=4是教学示例。SDA从机模型仅通过真实SCL/SDA总线交互。
// 本文件验证上述两组教学用例，不代表工程归档18项TB或板级验收结果。
//
// 图16-1：Scope=tb_chapter16_all；时间0~350ns。
// clk、rst_n、frame_start：Binary；live_bus、frame_bus：Hexadecimal。
// live=3时先保持frame=0；帧起点捕获3；live改A后frame保持3；下帧捕获A。
// 图16-2：观察第一次两字节连续读：A5、5A；前字节ACK、末字节NACK、STOP。
// 建议范围400000~525000ns（400~525us）：约414.459us完成A5并ACK，
// 约494.150us完成5A并NACK，514.072us产生STOP，520.049us报告i2c_done。
// root别名：scl/sda/sda_dir/sda_out/reg_cnt/reg_num/once_byte_done/
// i2c_data_r/i2c_ack/i2c_done/master_ack_window/i2c_state。
// i2c_ack是驱动器采样的从机确认，不能解释成主机的末字节ACK/NACK。
// 本地验证：57次快照检查、5笔I2C事务，CH16 PASS，errors=0。

module tb_chapter16_all;
    reg clk = 1'b0;
    always #9.765625 clk = ~clk;

    reg rst_n = 1'b0;
    reg frame_start = 1'b0;
    reg [3:0] live_bus = 4'h0;
    wire [3:0] frame_bus;
    integer snapshot_case = 0;
    integer snapshot_checks = 0;
    reg snapshot_complete = 1'b0;

    frame_snapshot_bus #(.WIDTH(4)) snapshot_dut (
        .clk(clk), .rst_n(rst_n), .frame_start(frame_start),
        .live_bus(live_bus), .frame_bus(frame_bus)
    );

    reg i2c_rst_n = 1'b0;
    reg [6:0] slave_addr = 7'h14;
    reg i2c_exec = 1'b0;
    reg i2c_rh_wl = 1'b1;
    reg [15:0] i2c_addr = 16'h814E;
    reg [7:0] i2c_data_w = 8'h96;
    reg bit_ctrl = 1'b1;
    reg [7:0] reg_num = 8'd2;
    wire [7:0] i2c_data_r;
    wire i2c_done, once_byte_done, scl, i2c_ack, dri_clk;
    tri1 sda;

    i2c_dri #(.CLK_FREQ(51_200_000), .I2C_FREQ(250_000), .WIDTH(8)) i2c_dut (
        .clk(clk), .rst_n(i2c_rst_n), .slave_addr(slave_addr),
        .i2c_exec(i2c_exec), .i2c_rh_wl(i2c_rh_wl), .i2c_addr(i2c_addr),
        .i2c_data_w(i2c_data_w), .bit_ctrl(bit_ctrl), .reg_num(reg_num),
        .i2c_data_r(i2c_data_r), .i2c_done(i2c_done),
        .once_byte_done(once_byte_done), .scl(scl), .ack(i2c_ack),
        .sda(sda), .dri_clk(dri_clk)
    );

    // Read-only aliases: no force/deposit or DUT state modification.
    wire sda_dir = i2c_dut.sda_dir;
    wire sda_out = i2c_dut.sda_out;
    wire [7:0] reg_cnt = i2c_dut.reg_cnt;
    wire [7:0] i2c_state = i2c_dut.cur_state;
    wire [6:0] i2c_counter = i2c_dut.cnt;
    wire master_ack_window = (i2c_state == 8'h40) &&
                             (i2c_counter >= 7'd33) &&
                             (i2c_counter <= 7'd39);

    integer error_count = 0;
    integer i2c_case = 0;
    integer transaction_count = 0;
    integer start_count = 0;
    integer stop_count = 0;
    integer slave_ack_count = 0;
    integer slave_nack_count = 0;
    integer master_ack_count = 0;
    integer master_nack_count = 0;
    integer rx_byte_count = 0;
    integer byte_done_count = 0;
    integer read_byte_count = 0;
    integer done_count = 0;
    reg i2c_complete = 1'b0;
    reg [7:0] rx_log [0:255];
    reg [7:0] read_log [0:255];

    task fail;
        input [8*160-1:0] message;
        begin
            error_count = error_count + 1;
            $display("CH16 FAIL at %0t: %0s", $time, message);
        end
    endtask

    task check_snapshot;
        input [3:0] expected_value;
        input [8*80-1:0] message;
        begin
            #0.001;
            snapshot_checks = snapshot_checks + 1;
            if (frame_bus !== expected_value) begin
                $display("SNAPSHOT expected=%h actual=%h", expected_value, frame_bus);
                fail(message);
            end
        end
    endtask

    task snapshot_step;
        input [3:0] next_live;
        input next_frame_start;
        input [3:0] expected_value;
        begin
            @(negedge clk);
            live_bus = next_live;
            frame_start = next_frame_start;
            @(posedge clk);
            check_snapshot(expected_value, "sweep capture/hold mismatch");
        end
    endtask

    integer snapshot_vector;
    reg [3:0] sweep_value;
    initial begin
        @(negedge clk);
        check_snapshot(4'h0, "initial reset");
        repeat (3) @(negedge clk);
        rst_n = 1'b1;                       // 78.125ns
        snapshot_case = 1;
        repeat (2) @(negedge clk);
        live_bus = 4'h3;                    // 117.1875ns
        @(posedge clk);
        check_snapshot(4'h0, "updated before frame_start");
        repeat (3) @(negedge clk);
        snapshot_case = 2;
        frame_start = 1'b1;                 // 175.78125ns
        @(posedge clk);
        check_snapshot(4'h3, "first frame did not capture 3");
        @(negedge clk);
        frame_start = 1'b0;
        repeat (2) @(negedge clk);
        snapshot_case = 3;
        live_bus = 4'hA;                    // 234.375ns
        @(posedge clk);
        check_snapshot(4'h3, "changed within a frame");
        repeat (3) @(negedge clk);
        snapshot_case = 4;
        frame_start = 1'b1;                 // 292.96875ns
        @(posedge clk);
        check_snapshot(4'hA, "second frame did not capture A");
        @(negedge clk);
        frame_start = 1'b0;
        repeat (3) @(negedge clk);
        live_bus = 4'h5;
        @(posedge clk);
        check_snapshot(4'hA, "second frame hold");

        // Assert reset between clock edges while the captured value is nonzero.
        @(negedge clk);
        #3;
        snapshot_case = 5;
        rst_n = 1'b0;
        check_snapshot(4'h0, "asynchronous reset did not clear snapshot");
        repeat (2) @(negedge clk);
        live_bus = 4'hF;
        frame_start = 1'b1;
        @(posedge clk);
        check_snapshot(4'h0, "frame_start overrode reset");
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_snapshot(4'hF, "capture after reset release");

        // Every 4-bit value, with two distinct mid-frame live changes each time.
        snapshot_case = 6;
        for (snapshot_vector = 0; snapshot_vector < 16;
             snapshot_vector = snapshot_vector + 1) begin
            sweep_value = snapshot_vector;
            snapshot_step(sweep_value, 1'b1, sweep_value);
            snapshot_step(sweep_value ^ 4'hF, 1'b0, sweep_value);
            snapshot_step(sweep_value ^ 4'h5, 1'b0, sweep_value);
        end
        @(negedge clk);
        frame_start = 1'b0;
        snapshot_case = 7;
        snapshot_complete = 1'b1;
        $display("CH16 SNAPSHOT complete: checks=%0d", snapshot_checks);
    end

    // Independent bus-level I2C slave. It observes only SCL/SDA, pulls SDA
    // low for zeros/ACK and releases it for ones/NACK. No DUT internals are
    // used to decide what the slave sends or to advance the slave state.
    localparam integer BUS_RX = 0, BUS_TX = 1, BUS_WAIT_STOP = 2;
    reg slave_drive_low = 1'b0;
    assign sda = slave_drive_low ? 1'b0 : 1'bz;
    reg inject_address_nack = 1'b0;
    reg bus_active = 1'b0;
    integer bus_mode = BUS_RX;
    integer bus_bit_count = 0;
    reg [7:0] rx_shift = 8'h00;
    reg next_byte_is_address = 1'b1;
    reg rx_byte_is_address = 1'b0;
    reg next_byte_is_read = 1'b0;
    reg slave_nack_this_byte = 1'b0;
    reg last_master_ack = 1'b1;
    integer slave_read_index = 0;
    reg [7:0] slave_tx_byte = 8'hA5;

    function [7:0] slave_read_pattern;
        input integer index;
        begin
            case (index % 4)
                0: slave_read_pattern = 8'hA5;
                1: slave_read_pattern = 8'h5A;
                2: slave_read_pattern = 8'hC3;
                default: slave_read_pattern = 8'h3C;
            endcase
        end
    endfunction

    always @(negedge sda) begin
        if (i2c_rst_n && scl === 1'b1) begin
            start_count = start_count + 1;
            bus_active = 1'b1;
            bus_mode = BUS_RX;
            bus_bit_count = 0;
            rx_shift = 8'h00;
            next_byte_is_address = 1'b1;
            next_byte_is_read = 1'b0;
            slave_nack_this_byte = 1'b0;
        end
    end

    always @(posedge sda) begin
        if (i2c_rst_n && scl === 1'b1 && bus_active) begin
            stop_count = stop_count + 1;
            bus_active = 1'b0;
            bus_mode = BUS_WAIT_STOP;
            slave_drive_low = 1'b0;
        end
    end

    always @(posedge scl) begin
        if (i2c_rst_n && bus_active) begin
            if (bus_mode == BUS_RX) begin
                if (bus_bit_count < 8) begin
                    rx_shift = {rx_shift[6:0], sda};
                    bus_bit_count = bus_bit_count + 1;
                    if (bus_bit_count == 8) begin
                        rx_log[rx_byte_count] = rx_shift;
                        rx_byte_count = rx_byte_count + 1;
                        rx_byte_is_address = next_byte_is_address;
                        next_byte_is_address = 1'b0;
                        next_byte_is_read = rx_byte_is_address && rx_shift[0];
                        slave_nack_this_byte = rx_byte_is_address &&
                            (inject_address_nack || rx_shift[7:1] != 7'h14);
                    end
                end
                else if (bus_bit_count == 8) begin
                    if (sda === 1'b0) slave_ack_count = slave_ack_count + 1;
                    else if (sda === 1'b1) slave_nack_count = slave_nack_count + 1;
                    else fail("unknown SDA at slave ACK/NACK");
                    bus_bit_count = 9;
                end
            end
            else if (bus_mode == BUS_TX) begin
                if (bus_bit_count < 8) bus_bit_count = bus_bit_count + 1;
                else if (bus_bit_count == 8) begin
                    last_master_ack = sda;
                    if (sda === 1'b0) master_ack_count = master_ack_count + 1;
                    else if (sda === 1'b1) master_nack_count = master_nack_count + 1;
                    else fail("unknown SDA at master ACK/NACK");
                    if (slave_read_index == reg_num - 1) begin
                        if (sda !== 1'b1) fail("last read byte was not NACKed");
                    end
                    else if (sda !== 1'b0) fail("non-final read byte was not ACKed");
                    bus_bit_count = 9;
                end
            end
        end
    end

    always @(negedge scl) begin
        if (i2c_rst_n && bus_active) begin
            if (bus_mode == BUS_RX) begin
                if (bus_bit_count == 8) slave_drive_low = !slave_nack_this_byte;
                else if (bus_bit_count == 9) begin
                    slave_drive_low = 1'b0;
                    bus_bit_count = 0;
                    rx_shift = 8'h00;
                    if (slave_nack_this_byte) bus_mode = BUS_WAIT_STOP;
                    else if (next_byte_is_read) begin
                        bus_mode = BUS_TX;
                        slave_read_index = 0;
                        slave_tx_byte = slave_read_pattern(0);
                        slave_drive_low = !slave_tx_byte[7];
                    end
                end
                else slave_drive_low = 1'b0;
            end
            else if (bus_mode == BUS_TX) begin
                if (bus_bit_count < 8)
                    slave_drive_low = !slave_tx_byte[7-bus_bit_count];
                else if (bus_bit_count == 8) slave_drive_low = 1'b0;
                else if (bus_bit_count == 9) begin
                    bus_bit_count = 0;
                    slave_drive_low = 1'b0;
                    if (last_master_ack === 1'b0) begin
                        slave_read_index = slave_read_index + 1;
                        slave_tx_byte = slave_read_pattern(slave_read_index);
                        slave_drive_low = !slave_tx_byte[7];
                    end
                    else bus_mode = BUS_WAIT_STOP;
                end
            end
        end
    end

    always @(posedge once_byte_done) begin
        if (i2c_rst_n) begin
            #0.001;
            byte_done_count = byte_done_count + 1;
            if (i2c_rh_wl) begin
                read_log[read_byte_count] = i2c_data_r;
                read_byte_count = read_byte_count + 1;
            end
        end
    end

    always @(posedge i2c_done) begin
        if (i2c_rst_n) begin
            done_count = done_count + 1;
            $display("CH16 I2C case=%0d done at %0t: reg_num=%0d data=%h ack=%b",
                     i2c_case, $time, reg_num, i2c_data_r, i2c_ack);
        end
    end

    task run_i2c_transaction;
        input read_not_write;
        input address_16bit;
        input [7:0] number_of_bytes;
        input reject_address;
        integer start_before, stop_before, slave_ack_before, slave_nack_before;
        integer master_ack_before, master_nack_before, rx_before;
        integer byte_before, read_before, done_before, timeout, header_bytes;
        integer verify_index;
        begin
            start_before = start_count;
            stop_before = stop_count;
            slave_ack_before = slave_ack_count;
            slave_nack_before = slave_nack_count;
            master_ack_before = master_ack_count;
            master_nack_before = master_nack_count;
            rx_before = rx_byte_count;
            byte_before = byte_done_count;
            read_before = read_byte_count;
            done_before = done_count;

            @(negedge dri_clk);
            i2c_rh_wl = read_not_write;
            bit_ctrl = address_16bit;
            reg_num = number_of_bytes;
            inject_address_nack = reject_address;
            i2c_exec = 1'b1;
            @(negedge dri_clk);
            i2c_exec = 1'b0;

            timeout = 0;
            while (done_count == done_before && timeout < 70000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (done_count == done_before) fail("I2C transaction timeout");
            // Let i2c_done and reg_cnt return to idle before checking/relaunch.
            repeat (4) @(negedge dri_clk);
            #0.001;
            transaction_count = transaction_count + 1;
            if (done_count != done_before + 1) fail("transaction done count");
            if (stop_count != stop_before + 1) fail("transaction STOP count");
            if (scl !== 1'b1 || sda !== 1'b1) fail("bus not idle after STOP");
            if (reg_cnt !== 8'd0) fail("register counter did not return to zero");

            if (reject_address) begin
                if (start_count != start_before + 1) fail("NACK transaction START count");
                if (rx_byte_count != rx_before + 1 || rx_log[rx_before] !== 8'h28)
                    fail("NACK address byte");
                if (slave_nack_count != slave_nack_before + 1 ||
                    slave_ack_count != slave_ack_before) fail("address NACK count");
                if (byte_done_count != byte_before) fail("address NACK completed data");
                if (master_ack_count != master_ack_before ||
                    master_nack_count != master_nack_before) fail("address NACK read ACKs");
                if (i2c_ack !== 1'b1) fail("address NACK not reported");
            end
            else begin
                header_bytes = address_16bit ? 3 : 2;
                if (rx_log[rx_before] !== 8'h28) fail("write address mismatch");
                if (address_16bit) begin
                    if (rx_log[rx_before+1] !== 8'h81 ||
                        rx_log[rx_before+2] !== 8'h4E) fail("16-bit register address");
                end
                else if (rx_log[rx_before+1] !== 8'h4E) fail("8-bit register address");
                if (byte_done_count != byte_before + number_of_bytes)
                    fail("once_byte_done count");
                if (slave_nack_count != slave_nack_before) fail("unexpected slave NACK");
                if (i2c_ack !== 1'b0) fail("slave ACK not reported");
                if (read_not_write) begin
                    if (start_count != start_before + 2) fail("missing repeated START");
                    if (rx_byte_count != rx_before + header_bytes + 1 ||
                        rx_log[rx_before+header_bytes] !== 8'h29)
                        fail("read address mismatch");
                    if (slave_ack_count != slave_ack_before + header_bytes + 1)
                        fail("read header ACK count");
                    if (master_ack_count != master_ack_before + number_of_bytes - 1 ||
                        master_nack_count != master_nack_before + 1)
                        fail("read ACK/NACK totals");
                    if (read_byte_count != read_before + number_of_bytes)
                        fail("read completion count");
                    for (verify_index = 0; verify_index < number_of_bytes;
                         verify_index = verify_index + 1) begin
                        if (read_log[read_before+verify_index] !== slave_read_pattern(verify_index))
                            fail("read data mismatch");
                    end
                end
                else begin
                    if (start_count != start_before + 1) fail("write START count");
                    if (rx_byte_count != rx_before + header_bytes + number_of_bytes)
                        fail("write byte count");
                    if (slave_ack_count != slave_ack_before + header_bytes + number_of_bytes)
                        fail("write ACK count");
                    if (read_byte_count != read_before ||
                        master_ack_count != master_ack_before ||
                        master_nack_count != master_nack_before) fail("write entered read mode");
                    for (verify_index = 0; verify_index < number_of_bytes;
                         verify_index = verify_index + 1) begin
                        if (rx_log[rx_before+header_bytes+verify_index] !== 8'h96)
                            fail("write payload mismatch");
                    end
                end
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        i2c_rst_n = 1'b1;
        #10000;
        i2c_case = 1;
        run_i2c_transaction(1'b1, 1'b1, 8'd2, 1'b0);
        #10000;
        i2c_case = 2;
        run_i2c_transaction(1'b1, 1'b0, 8'd1, 1'b0);
        #10000;
        i2c_case = 3;
        run_i2c_transaction(1'b1, 1'b1, 8'd3, 1'b0);
        #10000;
        i2c_case = 4;
        run_i2c_transaction(1'b0, 1'b1, 8'd2, 1'b0);
        #10000;
        i2c_case = 5;
        run_i2c_transaction(1'b1, 1'b1, 8'd1, 1'b1);
        i2c_case = 6;
        i2c_complete = 1'b1;
    end

    initial begin
        wait (snapshot_complete && i2c_complete);
        #100;
        if (snapshot_checks != 57 || transaction_count != 5 ||
            start_count != 8 || stop_count != 5 ||
            slave_ack_count != 16 || slave_nack_count != 1 ||
            master_ack_count != 3 || master_nack_count != 3 ||
            byte_done_count != 8 || read_byte_count != 6 || done_count != 5)
            fail("final coverage totals");
        if (error_count == 0)
            $display("CH16 PASS: snapshot_checks=%0d transactions=%0d starts=%0d stops=%0d slave_ack=%0d slave_nack=%0d master_ack=%0d master_nack=%0d data_bytes=%0d errors=0",
                     snapshot_checks, transaction_count, start_count, stop_count,
                     slave_ack_count, slave_nack_count, master_ack_count,
                     master_nack_count, byte_done_count);
        else $display("CH16 FAIL: errors=%0d", error_count);
    end

    initial begin
        #2800000;
        if (!snapshot_complete || !i2c_complete) fail("suite timeout");
    end
endmodule
