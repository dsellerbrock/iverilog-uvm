// break and continue apply to the innermost enclosing loop (IEEE
// 1800-2017/2023 12.8), also from a block that declares its own variables.
// Icarus runs such a block as a forked child thread. A break there disabled
// the loop's whole thread, ending the enclosing task, and a continue fell
// through into the statements after the block. OpenTitan
// kmac_app_monitor::process_trans breaks out of while (1) from a body that
// declares locals, and its monitor died after the first transaction.
module test;
  bit failed = 0;

  task automatic check(string what, int got, int expected);
    if (got !== expected) begin
      $display("FAILED %s: got %0d expected %0d", what, got, expected);
      failed = 1;
    end
  endtask

  class walker;
    int n;
    task run(output int after);
      after = 0;
      repeat (3) begin
        while (1) begin
          bit last;
          n++;
          last = (n % 2 == 0);
          if (last) break;
        end
        after++;
      end
    endtask
  endclass

  task automatic loops();
    int n, after, sum;

    n = 0; after = 0;
    repeat (2) begin
      while (1) begin
        int k;
        k = ++n;
        if (k % 3 == 0) break;
      end
      after++;
    end
    check("while break", n, 6);
    check("while break resumes", after, 2);

    sum = 0; after = 0;
    for (int i = 0; i < 6; i++) begin
      begin
        int k;
        k = i;
        if (k % 2) continue;
      end
      after++;
      sum += i;
    end
    check("for continue skips the rest", after, 3);
    check("for continue sum", sum, 6);

    n = 0;
    forever begin
      begin
        int k;
        k = ++n;
        begin
          int j;
          j = k;
          if (j == 4) break;
        end
      end
    end
    check("forever break from depth 2", n, 4);

    n = 0; sum = 0;
    do begin
      int k;
      k = ++n;
      if (k == 2) continue;
      sum += k;
    end while (n < 4);
    check("do-while continue", sum, 8);

    n = 0; sum = 0;
    repeat (5) begin
      int k;
      k = ++n;
      if (k == 4) break;
      sum += k;
    end
    check("repeat break", sum, 6);
  endtask

  // The monitor shape: a forever loop in a fork/join_any isolation block.
  bit stop;
  int beats, reqs;
  task automatic process_trans();
    forever begin
      while (1) begin
        bit last;
        beats++;
        last = (beats % 2 == 0);
        #1;
        if (last) break;
      end
      reqs++;
      if (reqs == 3) stop = 1;
    end
  endtask

  walker w = new;
  int after;
  initial begin
    loops();
    w.run(after);
    check("class method break", after, 3);
    check("class method iterations", w.n, 6);
    fork
      begin
        fork
          process_trans();
          wait (stop);
        join_any
        disable fork;
      end
    join
    check("isolated monitor requests", reqs, 3);
    if (!failed) $display("PASSED");
  end
endmodule
