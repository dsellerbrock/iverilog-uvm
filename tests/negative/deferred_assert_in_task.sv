// A deferred assertion inside a task is a loud unsupported form until the
// caller-process queue can retain captured arguments and activation lifetime.
module t;
  task check(int v);
    assert #0 (v == 1) else $display("nope");
  endtask
  initial check(1);
endmodule
