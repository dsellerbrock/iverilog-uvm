// IEEE 1800-2023 §15.3.2, §15.3.3, §15.3.4
// Negative keyCount in put(), get(), and try_get() shall result in an error
module test;
  semaphore sem;
  int ok;

  initial begin
    sem = new(1);
    // §15.3.4: negative try_get keyCount returns 0 and shall result in an error.
    ok = sem.try_get(-1);
    $display("try_get(-1) returned %0d", ok);

    // §15.3.2/§15.3.3: negative keyCount shall result in an error.
    sem.put(-1);
    sem.get(-1);
  end
endmodule
