// IEEE 1800-2017/2023 16.14.6: only the leading clock takes matured
// instances, and each taken instance starts a separate attempt.
module sva_proc_composite_queue;
  bit root, clk1, clk2, request, disabled;
  bit a = 1, b = 1;
  int batch = 1;
  int passes, failures, static_passes, errors;

  property p;
    (@(posedge clk1) 1'b1 |-> a) and (@(posedge clk2) 1'b1 |-> b);
  endproperty

  always @(posedge request)
    repeat (batch)
      check_p: assert property (@(posedge root) disable iff (disabled) 1'b1 |=> p)
        begin
          if ($sformatf("%m") != "sva_proc_composite_queue")
            $fatal(1, "unexpected procedural action scope %m");
          passes++;
        end else failures++;

  always assert property (@(posedge root) 1'b1 |=> p) begin
    if ($sformatf("%m") != "sva_proc_composite_queue")
      $fatal(1, "unexpected static action scope %m");
    static_passes++;
  end

  task automatic enqueue;
    request = 1; #1; request = 0;
  endtask

  task automatic lead;
    root = 1; #1; root = 0;
  endtask

  task automatic dest1;
    clk1 = 1; #1; clk1 = 0;
  endtask

  task automatic dest2;
    clk2 = 1; #1; clk2 = 0;
  endtask

  task automatic check(input int expected, input string phase);
    if (passes != expected || failures != 0) begin
      $display("%s: expected %0d passes, got %0d passes and %0d failures",
               phase, expected, passes, failures);
      errors++;
    end
  endtask

  initial begin
    #1;
    enqueue();
    dest1();
    check(0, "destination before root");
    lead();
    check(0, "root");
    dest1();
    check(0, "first destination after root");
    dest2();
    check(1, "second destination after root");

    batch = 2;
    enqueue();
    lead();
    dest1();
    check(1, "two instances waiting for second destination");
    dest2();
    check(3, "two separate attempts from one root");
    lead();
    dest1(); dest2();
    check(3, "root without enqueues");

    batch = 1;
    enqueue();
    $assertoff(0, check_p);
    $asserton(0, check_p);
    lead(); dest1(); dest2();
    check(3, "Off after maturity");

    request = 1;
    #0;
    $assertoff(0, check_p);
    #1; request = 0;
    $asserton(0, check_p);
    lead(); dest1(); dest2();
    check(3, "maturity while Off");

    enqueue();
    $assertkill(0, check_p);
    $asserton(0, check_p);
    lead(); dest1(); dest2();
    check(3, "Kill before leading clock");

    enqueue();
    lead(); dest1();
    $assertkill(0, check_p);
    $asserton(0, check_p);
    dest2();
    check(3, "Kill after start, before destination");

    enqueue();
    lead(); dest1();
    $assertoff(0, check_p);
    dest2();
    check(4, "Off allows in-flight attempt to finish");

    $asserton(0, check_p);
    root = 1; request = 1;
    #1; root = 0; request = 0;
    dest1(); dest2();
    check(5, "enqueue in the leading clock time step");

    batch = 2;
    enqueue();
    disabled = 1;
    lead();
    disabled = 0;
    dest1(); dest2();
    check(5, "instances disabled at their start");

    batch = 1;
    enqueue(); lead(); dest1();
    $assertpassoff(0, check_p);
    dest2();
    check(5, "pass action suppressed at dispatch");

    if (static_passes != 11) begin
      $display("static always assert: expected 11 passes, got %0d", static_passes);
      errors++;
    end
    if (errors) $fatal(1, "procedural composite queue: %0d errors", errors);
    $display("PASSED");
  end
endmodule
