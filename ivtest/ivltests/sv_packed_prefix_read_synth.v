module dut(input bit [1:0][2:0][7:0] words, input logic [2:0] idx,
           output bit [3:0] out);
  assign out = words[0][idx][0 +: 4];
endmodule

module test;
  bit [1:0][2:0][7:0] words;
  logic [2:0] idx;
  bit [3:0] out;
  dut d(.*);

  initial begin
    words = 48'h112233aabbcc;
    idx = 3;
    #1 if (out !== 4'b0000) $fatal(1, "OOB %b", out);
    idx = 1;
    #1 if (out !== 4'hb) $fatal(1, "valid %b", out);
    $display("PASSED");
  end
endmodule
