// An ANSI-style UDP header may name several input ports after one `input'
// (IEEE 1800-2017/2023 29.3, list_of_udp_port_identifiers): `primitive m(output
// y, input a, b, s);'. Only one identifier per `input' was accepted, so the
// grouped form was a syntax error.
primitive mux2(output y, input a, b, s);
  table
    // a b s : y
    0 ? 0 : 0;
    1 ? 0 : 1;
    ? 0 1 : 0;
    ? 1 1 : 1;
    0 0 x : 0;
    1 1 x : 1;
  endtable
endprimitive

primitive latch(output reg q, input d, e);
  table
    // d e : q : q+
    0 1 : ? : 0;
    1 1 : ? : 1;
    ? 0 : ? : -;
  endtable
endprimitive

module main;
  reg a, b, s, d, e;
  wire y, q;
  int errors;
  mux2 m(y, a, b, s);
  latch l(q, d, e);

  task automatic expect_y(string what, logic want);
    #1;
    if (y !== want) begin
      $display("FAILED %s: y=%b want %b", what, y, want);
      errors++;
    end
  endtask

  initial begin
    a = 1; b = 0; s = 0; expect_y("select a", 1'b1);
    s = 1; expect_y("select b", 1'b0);
    s = 1'bx; b = 1; expect_y("x select, equal inputs", 1'b1);
    b = 0; expect_y("x select, different inputs", 1'bx);
    e = 1; d = 1; #1;
    if (q !== 1'b1) begin $display("FAILED latch load"); errors++; end
    e = 0; d = 0; #1;
    if (q !== 1'b1) begin $display("FAILED latch hold"); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
