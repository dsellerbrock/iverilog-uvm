module test;
  logic [3:0] high;
  logic [3:0] low;
  logic [7:0] result;

  function automatic logic [7:0] constant_concat_assignment();
    logic [3:0] function_high;
    logic [3:0] function_low;
    return ({function_high, function_low} = 8'h69);
  endfunction

  localparam logic [7:0] CONSTANT_RESULT = constant_concat_assignment();

  initial begin
    if (CONSTANT_RESULT !== 8'h69)
      $fatal(1, "constant function concatenation assignment expression");

    high = 0;
    low = 0;
    result = ({high, low} = 8'hA5);
    if (high !== 4'hA || low !== 4'h5 || result !== 8'hA5)
      $fatal(1, "concatenation assignment expression value or side effect");
    if ($bits(({high, low} = 8'h3C)) != 8)
      $fatal(1, "concatenation assignment expression width");
    result = ({high, low} = 8'h3C);
    if (high !== 4'h3 || low !== 4'hC || result !== 8'h3C)
      $fatal(1, "concatenation assignment expression return value");
    if (({high, low} = 8'hF5) < 0)
      $fatal(1, "concatenation assignment expression must be unsigned");

    result = ({high[3:2], low[1:0]} = 4'h9);
    if (high !== 4'hB || low !== 4'h5 || result !== 8'h09)
      $fatal(1, "selected concatenation assignment expression");

    $display("PASSED");
  end
endmodule
