module test;
  bit failed = 1'b0;

  `define check(val, exp) do \
    if (val !== exp) begin \
      $display("FAILED(%0d): %s expected %02h, got %02h", \
               `__LINE__, `"val`", exp, val); \
      failed = 1'b1; \
    end \
  while (0)

  byte descending[3:0] = "AB\n";
  byte ascending[0:3];
  byte procedural[4];
  byte padded[0:3] = "AB";
  byte truncated[0:1];
  byte nested[0:1][3:0] = '{"AB\n", "CD\t"};

  assign ascending = "AB\n";

  initial begin
    procedural = "AB\n";
    truncated = "ABC";
    #1;

    `check(descending[3], 8'h41);
    `check(descending[2], 8'h42);
    `check(descending[1], 8'h0a);
    `check(descending[0], 8'h00);

    `check(ascending[0], 8'h41);
    `check(ascending[1], 8'h42);
    `check(ascending[2], 8'h0a);
    `check(ascending[3], 8'h00);

    `check(procedural[0], 8'h41);
    `check(procedural[1], 8'h42);
    `check(procedural[2], 8'h0a);
    `check(procedural[3], 8'h00);

    `check(padded[0], 8'h41);
    `check(padded[1], 8'h42);
    `check(padded[2], 8'h00);
    `check(padded[3], 8'h00);

    `check(truncated[0], 8'h41);
    `check(truncated[1], 8'h42);

    `check(nested[0][3], 8'h41);
    `check(nested[0][2], 8'h42);
    `check(nested[0][1], 8'h0a);
    `check(nested[0][0], 8'h00);
    `check(nested[1][3], 8'h43);
    `check(nested[1][2], 8'h44);
    `check(nested[1][1], 8'h09);
    `check(nested[1][0], 8'h00);

    if (!failed)
      $display("PASSED");
  end
endmodule
