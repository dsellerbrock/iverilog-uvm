// IEEE 1800-2017 §15.3 / IEEE 1800-2023 §15.3
// Semaphores: new(), put(), get(), try_get(), and FIFO queue order
module test;
  semaphore sem;
  int errors = 0;

  task automatic check(string msg, int cond);
    if (!cond) begin
      $display("FAILED: %s", msg);
      errors++;
    end else begin
      $display("PASSED: %s", msg);
    end
  endtask

  initial begin
    int ok;
    int wake_order[$];

    // 1. §15.3.1 new() default keyCount = 0
    sem = new();
    ok = sem.try_get(1);
    check("new() default is 0 keys", ok == 0);

    // 2. §15.3.2 put() default keyCount = 1
    sem.put();
    ok = sem.try_get(1);
    check("put() default adds 1 key", ok == 1);
    check("try_get(1) consumed key", sem.try_get(1) == 0);

    // 3. Multi-key new(), put(), try_get()
    sem = new(3);
    ok = sem.try_get(2);
    check("new(3) allows try_get(2)", ok == 1);
    ok = sem.try_get(2);
    check("try_get(2) fails with 1 key remaining", ok == 0);
    ok = sem.try_get(1);
    check("try_get(1) succeeds with 1 key remaining", ok == 1);
    check("semaphore empty after consuming all keys", sem.try_get(1) == 0);

    sem.put(2);
    check("put(2) adds 2 keys", sem.try_get(2) == 1);

    // 4. §15.3.3 get() blocking and wake on put()
    sem = new(0);
    fork
      begin
        #10;
        sem.put(1);
      end
      begin
        sem.get(1);
        check("get(1) blocks and unblocks after put(1)", $time == 10);
      end
    join

    // 5. FIFO waiting queue (§15.3.3)
    sem = new(0);
    fork
      begin
        #10;
        sem.get(1);
        wake_order.push_back(1);
      end
      begin
        #10;
        #0;
        sem.get(1);
        wake_order.push_back(2);
      end
      begin
        #20;
        sem.put(1);
        #10;
        sem.put(1);
        #10;
        check("FIFO waking count", wake_order.size() == 2);
        if (wake_order.size() == 2) begin
          check("FIFO order first arrival wakes first", wake_order[0] == 1);
          check("FIFO order second arrival wakes second", wake_order[1] == 2);
        end
      end
    join

    if (errors == 0) $display("PASS semaphore clause 15.3");
    else $fatal(1, "%0d semaphore checks failed", errors);
    $finish;
  end
endmodule
