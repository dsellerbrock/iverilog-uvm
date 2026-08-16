// A large fixed target must translate declared indexes in O(1) per element.
module test;
  localparam int N = 32768;
  logic fixed [N-1:0];
  logic [N-1:0] source;
  integer first;
  integer count;

  initial begin
    fixed = '{default:1'b0};
    source = '1;
    first = 0;
    count = N;
    {>>{fixed with [first +: count]}} = source;
    if (fixed[0] !== 1'b1 || fixed[N/2] !== 1'b1
        || fixed[N-1] !== 1'b1)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
