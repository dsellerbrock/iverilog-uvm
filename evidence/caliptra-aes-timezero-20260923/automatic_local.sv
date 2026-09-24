`timescale 1ns/1ps
package aes_reducer_pkg;
  function automatic logic [7:0] mul2(input logic [7:0] x);
    logic [7:0] out;
`ifdef WHOLE_ASSIGN
    out = {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
`else
    out[7] = x[6];
    out[6] = x[5];
    out[5] = x[4];
    out[4] = x[3] ^ x[7];
    out[3] = x[2] ^ x[7];
    out[2] = x[1];
    out[1] = x[0] ^ x[7];
    out[0] = x[7];
`endif
    return out;
  endfunction
endpackage

module aes_reducer_cell(input logic [7:0] x, output logic [7:0] y);
  import aes_reducer_pkg::*;
  always_comb y = mul2(x);
endmodule

module automatic_local;
  logic [7:0] a, b, ya, yb;
  aes_reducer_cell first_cell(a, ya);
`ifdef PAIR
  aes_reducer_cell second_cell(b, yb);
`endif
  initial begin
    a = 8'h01;
    b = 8'h02;
    #1;
    if (ya !== 8'h02) $fatal(1, "first cell wrong: %h", ya);
`ifdef PAIR
    if (yb !== 8'h04) $fatal(1, "second cell wrong: %h", yb);
`endif
    $display("REDUCER PASSED");
    $finish;
  end
endmodule
