// IEEE 1800-2017 27.4: the loop genvar is an implicit localparam whose
// value differs in every generated scope.  That value remains a constant
// expression in an SVA cycle delay and in $past's number_of_ticks argument.
//
// Three consecutive antecedents also prove that the symbolic implementation
// keeps every overlapping attempt, rather than a single pending flag.
module sv_assert_genvar_cycle_delay;
  logic clk = 0;
  logic req = 0;
  logic [3:1] ack = '0;
  integer ticks = 0;

  always #5 clk = ~clk;
  always_ff @(posedge clk) ticks <= ticks + 1;

  for (genvar n = 1; n <= 3; n++) begin : G
    integer passes = 0;
    integer failures = 0;

    A: assert property (@(posedge clk)
          req |-> ##n (ack[n] && $past(req, n) &&
                       ticks == $past(ticks, n) + n))
      passes = passes + 1;
    else
      failures = failures + 1;
  end

  task automatic drive(input logic r,
                       input logic a1, input logic a2, input logic a3);
    @(negedge clk);
    req = r;
    ack[1] = a1;
    ack[2] = a2;
    ack[3] = a3;
  endtask

  initial begin
    // Launch at c1/c2/c3.  For generated n=1 the acknowledgements are at
    // c2/c3/c4; for n=2 at c3/c4/c5; and for n=3 at c4/c5/c6.
    drive(1, 0, 0, 0); // c1
    drive(1, 1, 0, 0); // c2
    drive(1, 1, 1, 0); // c3
    drive(0, 1, 1, 1); // c4
    drive(0, 0, 1, 1); // c5
    drive(0, 0, 0, 1); // c6
    drive(0, 0, 0, 0); // c7 / flush
    @(negedge clk);

    if (G[1].passes != 3 || G[1].failures != 0)
      $display("FAILED -- n=1 passes=%0d failures=%0d",
               G[1].passes, G[1].failures);
    else if (G[2].passes != 3 || G[2].failures != 0)
      $display("FAILED -- n=2 passes=%0d failures=%0d",
               G[2].passes, G[2].failures);
    else if (G[3].passes != 3 || G[3].failures != 0)
      $display("FAILED -- n=3 passes=%0d failures=%0d",
               G[3].passes, G[3].failures);
    else
      $display("PASSED");
    $finish;
  end
endmodule
