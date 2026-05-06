// G28: interface arrays — declare `if_type name[N]` and access
// elements via `name[i].signal`.
// Pre-fix: array-typed interface instantiation triggered elaboration
// errors when accessing individual elements.
`timescale 1ns/1ps

interface bus_if(input logic clk);
  logic [7:0] data;
  logic       valid;
endinterface

module top;
  logic clk = 0;
  bus_if b [2] (.clk(clk));

  initial begin
    b[0].data  = 8'hAA;
    b[1].data  = 8'hBB;
    b[0].valid = 1;
    b[1].valid = 0;
    #1;
    if (b[0].data === 8'hAA && b[1].data === 8'hBB)
      $display("PASS: interface array element access works");
    else
      $display("FAIL: data mismatch b[0]=%0h b[1]=%0h", b[0].data, b[1].data);
    $finish;
  end
endmodule
