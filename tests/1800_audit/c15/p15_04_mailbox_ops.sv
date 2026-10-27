// IEEE 1800-2017/2023 §15.4.1–§15.4.8: typed mailbox operations.
module p15_04_mailbox_ops;
  mailbox #(int) unbounded;
  mailbox #(int) bounded;
  int failures = 0;

  task automatic check(string label, bit condition);
    if (!condition) begin
      failures++;
      $display("FAILED: %s", label);
    end
  endtask

  initial begin
    int value;
    int first;
    int second;
    int p1;
    int p2;
    int g1;
    bit put_done;
    bit get_done;
    bit peek1_done;
    bit peek2_done;
    bit get1_done;
    bit get2_done;

    unbounded = new();
    bounded = new(2);
    check("new() creates empty default-unbounded mailbox", unbounded.num() == 0);
    check("new(2) creates empty bounded mailbox", bounded.num() == 0);

    put_done = 0;
    fork
      begin
        unbounded.put(17);
        put_done = 1;
      end
    join_none
    #1;
    check("unbounded put does not block", put_done && unbounded.num() == 1);
    unbounded.get(value);
    check("get removes the queued message", value == 17 && unbounded.num() == 0);

    check("bounded try_put succeeds while space remains", bounded.try_put(10) > 0);
    bounded.put(20);
    check("put preserves FIFO message order", bounded.num() == 2);
    check("bounded try_put returns zero when full", bounded.try_put(30) == 0);
    bounded.peek(value);
    check("peek copies without removing", value == 10 && bounded.num() == 2);
    check("try_peek copies without removing", bounded.try_peek(value) > 0
          && value == 10 && bounded.num() == 2);
    check("try_get removes the first queued message", bounded.try_get(value) > 0
          && value == 10 && bounded.num() == 1);
    bounded.get(value);
    check("get removes the next queued message", value == 20 && bounded.num() == 0);
    check("try_get returns zero when empty", bounded.try_get(value) == 0);
    check("try_peek returns zero when empty", bounded.try_peek(value) == 0);

    get_done = 0;
    fork
      begin
        bounded.get(value);
        get_done = 1;
      end
    join_none
    #1;
    check("get blocks on an empty mailbox", !get_done);
    bounded.put(40);
    wait (get_done);
    check("put wakes a blocked get", value == 40 && bounded.num() == 0);

    bounded.put(50);
    bounded.put(60);
    put_done = 0;
    fork
      begin
        bounded.put(70);
        put_done = 1;
      end
    join_none
    #1;
    check("put blocks when a bounded mailbox is full", !put_done && bounded.num() == 2);
    bounded.get(value);
    check("bounded queue starts in FIFO order", value == 50);
    wait (put_done);
    check("get wakes blocked put and preserves queue", bounded.num() == 2);
    bounded.get(value);
    check("blocked put follows existing messages", value == 60);
    bounded.get(value);
    check("blocked put message is last", value == 70 && bounded.num() == 0);

    peek1_done = 0;
    peek2_done = 0;
    get_done = 0;
    fork
      begin
        #1;
        bounded.peek(p1);
        peek1_done = 1;
      end
      begin
        #2;
        bounded.peek(p2);
        peek2_done = 1;
      end
      begin
        #3;
        bounded.get(g1);
        get_done = 1;
      end
    join_none
    #4;
    check("peek and get wait on an empty mailbox", !peek1_done && !peek2_done && !get_done);
    bounded.put(80);
    wait (peek1_done && peek2_done && get_done);
    check("one put wakes multiple peek/get waiters", p1 == 80 && p2 == 80 && g1 == 80);
    check("get removes the message after peek waiters copy it", bounded.num() == 0);

    get1_done = 0;
    get2_done = 0;
    fork
      begin
        #1;
        bounded.get(first);
        get1_done = 1;
      end
      begin
        #2;
        bounded.get(second);
        get2_done = 1;
      end
    join_none
    #4;
    bounded.put(90);
    bounded.put(100);
    wait (get1_done && get2_done);
    check("blocked get waiters receive messages in FIFO order", first == 90
          && second == 100 && bounded.num() == 0);

    if (failures != 0)
      $fatal(1, "%0d mailbox checks failed", failures);
    $display("PASS mailbox clause 15.4 core");
    $finish;
  end
endmodule
