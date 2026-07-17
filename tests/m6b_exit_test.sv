// M6B: $exit program control task (IEEE 1800-2017 24.7). $exit ends the
// calling program; for the common single-program testbench that ends the
// simulation. Verify $exit halts execution (the line after it must not
// run) and the simulation ends without hitting the watchdog timeout.
module m6b_exit_test_top;
  logic clk = 0;
  always #5 clk = ~clk;

  program tb;
    initial begin
      repeat (2) @(posedge clk);
      $display("PASS: m6b $exit reached (t=%0t); ending sim", $time);
      $exit;
      // If $exit did not end the program, this FAIL line prints and the
      // harness catches it.
      $display("FAIL: m6b $exit did not terminate the program");
    end
  endprogram

  // Watchdog: if $exit failed to end the simulation, this fires.
  initial begin
    #100000;
    $display("FAIL: m6b $exit did not end the simulation (watchdog)");
    $finish(1);
  end
endmodule
