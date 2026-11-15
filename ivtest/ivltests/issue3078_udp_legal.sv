primitive p(q, a, b);
  output reg q;
  input a, b;
  table
    (01) 0 : ? : 1;
    0 f : ? : 0;
    ? 1 : ? : 0;
  endtable
endprimitive
module top;
  wire q;
  reg a, b;
  p inst(q, a, b);
  initial begin
    a = 0; b = 0;
    #1 a = 1;
    #1 if (q !== 1) $fatal(1, "rising edge failed");
    a = 0; b = 1;
    #1 b = 0;
    #1 if (q !== 0) $fatal(1, "falling edge failed");
    $display("PASS");
  end
endmodule
