module test;
  integer failures = 0;

  task check;
    begin
      a1: assert (1'b0) else failures += 1;
      a2: assert (1'b0) else failures += 1;
    end
  endtask

  initial begin
    $assertoff(0, a1, a2);
    check();
    $display("off failures=%0d", failures);

    $asserton(0, a1, a2);
    check();
    $display("on failures=%0d", failures);

    $assertkill(0, a1, a2);
    check();
    $display("kill failures=%0d", failures);

    $assertoff;
    check();
    $display("global off failures=%0d", failures);
    $asserton;
    check();
    $display("global on failures=%0d", failures);
    $finish;
  end
endmodule
