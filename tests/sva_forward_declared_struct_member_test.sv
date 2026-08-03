module sva_forward_declared_struct_member_test;
  typedef struct packed {
    logic [1:0] flags;
  } status_t;

  bit clk, rst_n;
  int passes, failures;

  // Module items are order-independent. The synthesized assertion checker
  // must bind the packed-struct signal declared later in this module.
  assert property (@(posedge clk) disable iff (!rst_n)
                   later_status.flags[0])
    passes++; else failures++;

  status_t later_status;

  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    later_status = '0;
    @(negedge clk);
    later_status.flags[0] = 1;
    rst_n = 1;
    @(negedge clk);
    rst_n = 0;
    if (passes != 1 || failures != 0)
      $fatal(1, "forward struct member sampling failed: %0d/%0d",
             passes, failures);
    $display("PASS: SVA binds a later module-scope struct declaration");
    $finish;
  end
endmodule
