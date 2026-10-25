// IEEE 1800-2017/2023 §18.14: thread and object random stability.
class Packet;
  rand int unsigned val;
endclass

module test;
  int unsigned x1, x2, y1, y2;

  task automatic run_thread_stability(input bit delay_first,
                                      output int unsigned rx,
                                      output int unsigned ry);
    process thread;
    thread = process::self();
    thread.srandom(100);
    fork
      begin
        if (delay_first) #5;
        rx = $urandom();
      end
      begin
        if (!delay_first) #5;
        ry = $urandom();
      end
    join
  endtask

  task automatic run_object_stability();
    Packet p1, p2;
    process thread;
    int unsigned val_p1_ref, val_p1_test, dummy;

    thread = process::self();
    thread.srandom(200);
    p1 = new;
    void'(p1.randomize());
    val_p1_ref = p1.val;

    thread = process::self();
    thread.srandom(200);
    p1 = new;
    dummy = $urandom();
    dummy = $random;
    p2 = new;
    void'(p2.randomize());
    void'(p1.randomize());
    val_p1_test = p1.val;

    if (val_p1_ref !== val_p1_test)
      $fatal(1, "Object stability changed after unrelated random calls");
  endtask

  initial begin
    run_thread_stability(1'b0, x1, y1);
    #10;
    run_thread_stability(1'b1, x2, y2);
    if (x1 !== x2 || y1 !== y2)
      $fatal(1, "Thread scheduling order changed $urandom values");

    run_object_stability();
    $display("PASS random stability clause 18.14");
  end
endmodule
