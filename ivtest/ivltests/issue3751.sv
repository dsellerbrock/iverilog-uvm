module issue3751;
  reg signed [3:0] s, ones;
  reg [3:0] u;
  wire signed [3:0] and_value = s & ones;
  wire signed [3:0] or_value = s | ones;
  wire signed [3:0] xor_value = s ^ ones;
  wire signed [3:0] xnor_value = s ~^ ones;
  wire signed [3:0] not_value = ~s;
  wire signed [3:0] plus_value = +s;
  wire signed [7:0] wide_value = s & ones;
  wire [3:0] unsigned_sink = s & ones;
  wire [3:0] mixed_left = s & u;
  wire [3:0] mixed_right = u & s;
  wire signed [7:0] constant_not = ~4'sb1x01;
  wire [3:0] constant_mixed = (~4'sb1x01) & 4'b1111;
  wire signed [3:0] floating;
  wire signed [3:0] floating_not = ~floating;
  wire signed [3:0] floating_plus = +floating;

  integer and_events = 0, or_events = 0, xor_events = 0, xnor_events = 0;
  integer not_events = 0, plus_events = 0, wide_events = 0;
  integer and_expr_events = 0, not_expr_events = 0, plus_expr_events = 0;

  always @(and_value) and_events = and_events + 1;
  always @(or_value) or_events = or_events + 1;
  always @(xor_value) xor_events = xor_events + 1;
  always @(xnor_value) xnor_events = xnor_events + 1;
  always @(not_value) not_events = not_events + 1;
  always @(plus_value) plus_events = plus_events + 1;
  always @(wide_value) wide_events = wide_events + 1;
  always @(s & ones) and_expr_events = and_expr_events + 1;
  always @(~s) not_expr_events = not_expr_events + 1;
  always @(+s) plus_expr_events = plus_expr_events + 1;

  task check_values;
    input [3:0] a, o, x, nx, n, p, mixed;
    input [7:0] wide;
    begin
      if ({and_value, or_value, xor_value, xnor_value, not_value, plus_value}
          !== {a, o, x, nx, n, p})
        $fatal(1, "and=%b or=%b xor=%b xnor=%b ~s=%b +s=%b",
               and_value, or_value, xor_value, xnor_value, not_value, plus_value);
      if (wide_value !== wide || unsigned_sink !== a)
        $fatal(1, "wide=%b unsigned sink=%b", wide_value, unsigned_sink);
      if (mixed_left !== mixed || mixed_right !== mixed)
        $fatal(1, "mixed signedness left=%b right=%b", mixed_left, mixed_right);
    end
  endtask

  task check_events;
    input integer binary_count, unary_count;
    begin
      if (and_events != binary_count || or_events != binary_count
          || xor_events != binary_count || xnor_events != binary_count
          || wide_events != binary_count || not_events != unary_count
          || plus_events != unary_count)
        $fatal(1, "output event counts and=%0d or=%0d xor=%0d xnor=%0d wide=%0d ~s=%0d +s=%0d",
               and_events, or_events, xor_events, xnor_events, wide_events,
               not_events, plus_events);
      if (and_expr_events != binary_count || not_expr_events != unary_count
          || plus_expr_events != unary_count)
        $fatal(1, "event-expression counts and=%0d ~s=%0d +s=%0d",
               and_expr_events, not_expr_events, plus_expr_events);
    end
  endtask

  initial begin
    s = 4'b1x01;
    ones = 4'b1111;
    u = 4'b1111;
    #1;
    check_values(4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'b1x01, 8'bx);
    if (constant_not !== 8'bx || constant_mixed !== 4'b0x10)
      $fatal(1, "constant ~ signed=%b mixed=%b", constant_not, constant_mixed);
    if (floating_not !== 4'bx || floating_plus !== 4'bx)
      $fatal(1, "first all-Z input ~=%b +=%b", floating_not, floating_plus);

    and_events = 0;
    or_events = 0;
    xor_events = 0;
    xnor_events = 0;
    not_events = 0;
    plus_events = 0;
    wide_events = 0;
    and_expr_events = 0;
    not_expr_events = 0;
    plus_expr_events = 0;

    s = 4'b1001;
    #1;
    check_values(4'h9, 4'hf, 4'h6, 4'h9, 4'h6, 4'h9, 4'h9, 8'hf9);
    check_events(1, 1);

    s = 4'b1z01;
    #1;
    check_values(4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'b1x01, 8'bx);
    check_events(2, 2);

    s = 4'b1x01;
    #1;
    check_values(4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'bx, 4'b1x01, 8'bx);
    check_events(2, 2);

    s = 4'b1001;
    #1;
    check_values(4'h9, 4'hf, 4'h6, 4'h9, 4'h6, 4'h9, 4'h9, 8'hf9);
    check_events(3, 3);

    ones = 4'bz111;
    #1;
    check_values(4'bx, 4'bx, 4'bx, 4'bx, 4'h6, 4'h9, 4'h9, 8'bx);
    check_events(4, 3);

    ones = 4'b1111;
    #1;
    check_values(4'h9, 4'hf, 4'h6, 4'h9, 4'h6, 4'h9, 4'h9, 8'hf9);
    check_events(5, 3);
    $display("PASSED");
  end
endmodule
