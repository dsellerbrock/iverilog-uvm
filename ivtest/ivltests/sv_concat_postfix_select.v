module test;
  logic [7:0] hi = 8'hac;
  logic [7:0] lo = 8'h53;
  integer base = 6;
  integer calls;
  logic [7:0] result;

  function automatic logic [7:0] next_value(input logic [7:0] value);
    calls += 1;
    return value;
  endfunction

  initial begin
    if ({hi,lo}[0] !== 1'b1)
      $fatal(1, "bit select");
    if ({hi,lo}[9:6] !== 4'h1)
      $fatal(1, "constant part select");
    if ({hi,lo}[base +: 4] !== 4'h1)
      $fatal(1, "upward indexed part select");
    if ({hi,lo}[base+3 -: 4] !== 4'h1)
      $fatal(1, "downward indexed part select");

    result = {hi,lo}[15:12] + {hi,lo}[3:0];
    if (result !== 8'h0d)
      $fatal(1, "selects inside an expression");

    calls = 0;
    result = {next_value(hi),next_value(lo)}[9:6];
    if (result !== 8'h01 || calls != 2)
      $fatal(1, "concatenation operands evaluated more than once");

    $display("PASSED");
  end
endmodule
