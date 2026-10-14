`timescale 1ns/1ps
primitive udp_xor(y, a, b);
  output y;
  input a, b;
  table
    0 0 : 0;
    0 1 : 1;
    1 0 : 1;
    1 1 : 0;
  endtable
endprimitive
module top;
  reg [31:0] a, b, en;
  wire [31:0] gate_out, udp_out, tri_out;
  genvar g;
  generate for (g = 0; g < 32; g = g + 1) begin : cells
    and (strong1, pull0) u_and(gate_out[g], a[g], b[g]);
    udp_xor u_udp(udp_out[g], a[g], b[g]);
    bufif1 (strong1, pull0) u_buf(tri_out[g], a[g], en[g]);
  end endgenerate
  integer i;
  initial begin
    a = 0; b = 32'hffffffff; en = 0;
    for (i = 0; i < 640000; i = i + 1) begin
      #1 a = a + 32'h01010101;
      b = {b[30:0], b[31]};
      en = i;
    end
    $display("gates=%h udp=%h tri=%h", gate_out, udp_out, tri_out);
    $finish;
  end
endmodule
