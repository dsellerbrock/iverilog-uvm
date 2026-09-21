module wide_valid_boundaries(input logic clk, output logic [7:0] mem0,mem1);
 logic [7:0] mem[0:1];
 always_ff @(posedge clk) begin mem[80'd0]<=8'h10; mem[80'd1]<=8'h20; end
 assign mem0=mem[0]; assign mem1=mem[1];
endmodule
module tb_wide_valid_boundaries;
 logic clk=0;logic[7:0]mem0,mem1;wide_valid_boundaries dut(.*);
 initial begin #1 clk=1;#1 clk=0;if({mem0,mem1}!==16'h1020)$fatal(1,"valid constants lost");$display("PASS");$finish(0);end
endmodule
