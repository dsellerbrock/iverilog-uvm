// IEEE 1800-2023 37.64: a procedural assignment has vpiLhs and vpiRhs
// expressions; 37.79: so does a force, and a release has vpiLhs (#3057);
// 37.78: a return statement has vpiCondition. The handles are generated
// when the design is compiled with a user VPI module (-m).
module top;
  logic [7:0] a, b = 8'd3, c = 8'd4;
  logic [3:0] hi = 4'hA, lo = 4'h5;
  logic [7:0] mem [0:3];
  logic x = 0;

  task assignments;
    a = b + c;
    mem[2] = a;
    a[3:0] = 4'd5;
    {hi, lo} = b;
    b <= ~c;
    force x = 1'b1;
    release x;
  endtask

  // The reproducer of #3042: operands in an automatic scope.
  task automatic check;
    integer i;
    i = 0;
    if (i == 0) i = 1; else i = 2;
  endtask

  function automatic int next(input int n);
    return n + 1;
  endfunction

  initial begin
    $probe_stmt_exprs;
    #1 force x = 1'b1;
    #1 release x;
    #1 $probe_stmt_done;
    $finish;
  end
endmodule
