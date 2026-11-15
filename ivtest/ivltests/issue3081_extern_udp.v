// IEEE 1800-2023 29.3 (Syntax 29-1): an extern UDP declaration, then the
// definition, which matches it or takes its ports with (.*). Provisional
// reading: 23.5 (extern modules) applied to UDPs.
extern primitive issue3081_buf(output q, input a);
extern primitive issue3081_xor(q, a, b);

module issue3081_extern_udp;
  wire q, x;
  logic a = 1, b = 0;
  issue3081_buf u(q, a);
  issue3081_xor v(x, a, b);
  initial begin
    #1 if (q !== 1'b1 || x !== 1'b1) $display("FAILED q=%b x=%b", q, x);
    b = 1;
    #1 if (x !== 1'b0) $display("FAILED x=%b", x);
    $display("PASSED");
  end
endmodule

primitive issue3081_buf(output q, input a);
  table 0 : 0; 1 : 1; endtable
endprimitive

primitive issue3081_xor(.*);
  output q;
  input a, b;
  table
    0 0 : 0;
    0 1 : 1;
    1 0 : 1;
    1 1 : 0;
  endtable
endprimitive
