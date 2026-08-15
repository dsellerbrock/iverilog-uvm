// A cap+1 fixed selection must reject before the store loop and preserve data.
module test;
  localparam int N = 1048577;
  class holder;
    logic fixed [N-1:0];
  endclass

  logic fixed [N-1:0];
  logic [N-1:0] source;
  logic [N-1:0] result;
  bit dyn[];
  holder h;
  integer first;
  integer count;

  initial begin
    fixed[0] = 1'b1;
    fixed[N-1] = 1'b0;
    source = '1;
    first = 0;
    count = N;
    {>>{fixed with [first +: count]}} = source;
    if (fixed[0] !== 1'b1 || fixed[N-1] !== 1'b0)
      $display("FAILED");

    h = new;
    h.fixed[0] = 1'b1;
    h.fixed[N-1] = 1'b0;
    {>>{h.fixed with [first +: count]}} = source;
    if (h.fixed[0] !== 1'b1 || h.fixed[N-1] !== 1'b0)
      $display("FAILED");

    dyn = new[N];
    result = {>>{dyn with [first +: count]}};
    if (result !== '0)
      $display("FAILED");

    if (fixed[0] === 1'b1 && fixed[N-1] === 1'b0
        && h.fixed[0] === 1'b1 && h.fixed[N-1] === 1'b0
        && result === '0)
      $display("PASSED");
  end
endmodule
