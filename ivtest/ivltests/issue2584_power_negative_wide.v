module issue2584_power_negative_wide;
  logic signed [99:0] zero = 0;
  logic signed [99:0] minus_one = -1;
  logic signed [99:0] minus_two = -2;
  logic signed [99:0] plus_two = 2;
  logic signed [99:0] neg_one = -1;
  logic signed [99:0] neg_two = -2;
  wire signed [99:0] net_zero = zero ** neg_one;
  wire signed [99:0] net_minus_one_odd = minus_one ** neg_one;
  wire signed [99:0] net_minus_one_even = minus_one ** neg_two;
  wire signed [99:0] net_minus_two = minus_two ** neg_one;
  wire signed [99:0] net_plus_two = plus_two ** neg_one;

  initial begin
    #1;
    if ((zero ** neg_one) !== 100'bx ||
        (minus_one ** neg_one) !== -100'sd1 ||
        (minus_one ** neg_two) !== 100'sd1 ||
        (minus_two ** neg_one) !== 100'sd0 ||
        (plus_two ** neg_one) !== 100'sd0)
      $fatal(1, "thread evaluation of wide negative powers failed");
    if (net_zero !== 100'bx || net_minus_one_odd !== -100'sd1 ||
        net_minus_one_even !== 100'sd1 || net_minus_two !== 100'sd0 ||
        net_plus_two !== 100'sd0)
      $fatal(1, "net evaluation of wide negative powers failed");
    $display("PASS wide negative power cases");
  end
endmodule
