// A deferred assertion inside a task is a (loud) named sorry for now:
// the hidden per-instance state would need per-activation treatment.
module t;
  task check(int v);
    assert #0 (v == 1) else $display("nope");
  endtask
  initial check(1);
endmodule
