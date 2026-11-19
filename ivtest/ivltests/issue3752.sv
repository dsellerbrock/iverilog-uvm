module issue3752;
  reg signed [3:0] s = 4'b0000;
  reg [3:0] u = 4'b0000;

  wire [5:0] signed_reductions = {&s, ~&s, |s, ~|s, ^s, ~^s};
  wire [5:0] unsigned_reductions = {&u, ~&u, |u, ~|u, ^u, ^~u};
  wire logical_not = !s;
  wire [4:0] wide_and = &s;

  task check;
    input [5:0] expected_signed, expected_unsigned;
    input expected_not;
    input [4:0] expected_wide;
    begin
      if (signed_reductions !== expected_signed)
        $fatal(1, "signed %b: reductions %b, expected %b",
               s, signed_reductions, expected_signed);
      if (unsigned_reductions !== expected_unsigned)
        $fatal(1, "unsigned %b: reductions %b, expected %b",
               u, unsigned_reductions, expected_unsigned);
      if (logical_not !== expected_not)
        $fatal(1, "!%b = %b, expected %b", s, logical_not, expected_not);
      if (wide_and !== expected_wide)
        $fatal(1, "wide &%b = %b, expected %b", s, wide_and, expected_wide);
    end
  endtask

  initial begin
    #1;
    check(6'b010101, 6'b010101, 1'b1, 5'b00000);

    s = 4'b1x01;
    u = 4'b1x01;
    #1;
    check(6'bxxxxxx, 6'b0110xx, 1'b0, 5'b0000x);

    s[2] = 1'b1;
    u[2] = 1'b1;
    #1;
    check(6'b011010, 6'b011010, 1'b0, 5'b00000);

    s[2] = 1'bz;
    u[2] = 1'bz;
    #1;
    check(6'bxxxxxx, 6'b0110xx, 1'b0, 5'b0000x);

    s[2] = 1'b1;
    u[2] = 1'b1;
    s[1] = 1'b1;
    u[1] = 1'b1;
    #1;
    check(6'b101001, 6'b101001, 1'b0, 5'b00001);

    $display("PASSED");
  end
endmodule
