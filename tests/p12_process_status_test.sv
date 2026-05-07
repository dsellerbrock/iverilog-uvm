// p12: G07 — process introspection — process::self() returns valid handle
module top;
  task automatic check_self();
    automatic process p = process::self();
    if (p == null)
      $display("FAIL: process::self() returned null");
    else
      $display("PASS: process status p12");
  endtask
  initial begin
    check_self();
    $finish;
  end
endmodule
