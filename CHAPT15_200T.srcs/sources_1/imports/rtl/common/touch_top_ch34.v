`timescale 1ns/1ps
module touch_top_ch34 #(parameter integer CLK_FREQ=50_000_000,parameter integer I2C_FREQ=250_000,parameter integer REG_NUM_WID=8)(
 input wire clk,input wire rst_n,output wire touch_rst_n,inout wire touch_int,output wire touch_scl,inout wire touch_sda,output wire [31:0] data,
 output wire dbg_i2c_ack,output wire dbg_i2c_done,output wire dbg_once_byte_done,output wire [7:0] dbg_i2c_data_r,
 output wire dbg_touch_valid,output wire dbg_ft_flag,output wire [15:0] dbg_chip_version,output wire [15:0] dbg_x,output wire [15:0] dbg_y,output wire [6:0] dbg_state);
wire [6:0] slave_addr; wire i2c_exec,i2c_rh_wl,bit_ctrl,i2c_done,once_byte_done,i2c_ack,dri_clk;
wire [15:0] i2c_addr; wire [7:0] i2c_data_w,i2c_data_r; wire [REG_NUM_WID-1:0] reg_num;
wire [15:0] lcd_id_probe=16'h0000;
i2c_dri #(.CLK_FREQ(CLK_FREQ),.I2C_FREQ(I2C_FREQ),.WIDTH(REG_NUM_WID)) u_i2c_dri(
 .clk(clk),.rst_n(rst_n),.slave_addr(slave_addr),.i2c_exec(i2c_exec),.i2c_rh_wl(i2c_rh_wl),.i2c_addr(i2c_addr),.i2c_data_w(i2c_data_w),.bit_ctrl(bit_ctrl),.reg_num(reg_num),.i2c_data_r(i2c_data_r),.i2c_done(i2c_done),.once_byte_done(once_byte_done),.scl(touch_scl),.ack(i2c_ack),.sda(touch_sda),.dri_clk(dri_clk));
touch_dri #(.WIDTH(REG_NUM_WID)) u_touch_dri(
 .clk(dri_clk),.rst_n(rst_n),.slave_addr(slave_addr),.i2c_exec(i2c_exec),.i2c_rh_wl(i2c_rh_wl),.i2c_addr(i2c_addr),.i2c_data_w(i2c_data_w),.bit_ctrl(bit_ctrl),.reg_num(reg_num),.i2c_data_r(i2c_data_r),.i2c_ack(i2c_ack),.i2c_done(i2c_done),.once_byte_done(once_byte_done),.lcd_id(lcd_id_probe),.data(data),.touch_rst_n(touch_rst_n),.touch_int(touch_int),.dbg_touch_valid(dbg_touch_valid),.dbg_ft_flag(dbg_ft_flag),.dbg_chip_version(dbg_chip_version),.dbg_x(dbg_x),.dbg_y(dbg_y),.dbg_state(dbg_state));
assign dbg_i2c_ack=i2c_ack; assign dbg_i2c_done=i2c_done; assign dbg_once_byte_done=once_byte_done; assign dbg_i2c_data_r=i2c_data_r;
endmodule
