// IEEE 1800-2023 §15.3.1 (p. 373)
// A negative initial count is legal, but keys must become positive before get/try_get can procure them.
module test;
  semaphore sem;
  int ok;

  initial begin
    sem = new(-1);
    ok = sem.try_get(1);
    $display("RESULT: new(-1) initial try_get(1) returned %0d (expected 0)", ok);

    sem.put(1);
    ok = sem.try_get(1);
    $display("RESULT: after put(1) try_get(1) returned %0d (expected 0)", ok);

    sem.put(1);
    ok = sem.try_get(1);
    $display("RESULT: after second put(1) try_get(1) returned %0d (expected 1)", ok);
    $finish;
  end
endmodule
