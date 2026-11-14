module issue3032_semaphore_fifo;
  semaphore s = new(0);
  semaphore cancelled = new(0);
  int order[$];
  bit released = 0;

  initial begin
    fork
      begin s.get(2); order.push_back(1); end
      begin #1; s.get(1); order.push_back(2); end
      begin
        #2; s.put(1);
        #1; if (order.size() != 0) $fatal(1, "waiter overtook queue head");
        s.put(2);
      end
    join
    if (order.size() != 2 || order[0] != 1 || order[1] != 2)
      $fatal(1, "incorrect waiter order");

    fork
      begin : head_waiter
        cancelled.get(2);
        $fatal(1, "cancelled waiter resumed");
      end
      begin #1; cancelled.get(1); released = 1; end
      begin
        #2; cancelled.put(1);
        #1; if (released) $fatal(1, "cancel test overtook queue head");
        disable head_waiter;
      end
    join
    if (!released) $fatal(1, "next waiter not released after cancellation");
    $display("PASS");
    $finish(0);
  end
  initial begin #100; $fatal(1, "timeout"); end
endmodule
