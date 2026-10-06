`timescale 1ns/1ps
module pulse_stretcher #(parameter integer HOLD_CYCLES=25_000_000)(input wire clk,input wire rst_n,input wire pulse_in,output wire level_out);
reg [31:0] cnt;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) cnt<=32'd0;
 else if(pulse_in) cnt<=HOLD_CYCLES;
 else if(cnt!=0) cnt<=cnt-32'd1;
end
assign level_out=(cnt!=0);
endmodule
