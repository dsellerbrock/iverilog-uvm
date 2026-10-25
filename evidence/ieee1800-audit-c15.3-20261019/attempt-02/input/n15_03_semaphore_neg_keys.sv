// IEEE 1800-2023 §15.3.2, §15.3.3, §15.3.4
// Negative keyCount in put(), get(), and try_get() shall result in an error
module test;
  semaphore sem_try;
  semaphore sem_put;
  semaphore sem_get;
  int ok;

  initial begin
    sem_try = new(10);
    ok = sem_try.try_get(-1);
    $display("RESULT: try_get(-1) returned %0d (expected error)", ok);

    sem_put = new(0);
    sem_put.put(-1);
    $display("RESULT: put(-1) returned without error");
    if (sem_put.try_get(1000)) begin
      $display("RESULT: put(-1) corrupted key count, acquired 1000 keys from empty semaphore");
    end

    sem_get = new(1);
    fork
      begin
        sem_get.get(-1);
        $display("RESULT: get(-1) returned without error");
      end
      begin
        #10;
        $display("RESULT: get(-1) blocked indefinitely waiting for 2^32-1 keys (expected error)");
      end
    join_any
    disable fork;

    $display("NEGATIVE PROBE FINISHED");
    $finish;
  end
endmodule
