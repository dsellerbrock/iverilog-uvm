class semaphore;
  int tag = 42;
endclass

module p26_07_std;
  std::semaphore ss;
  std::mailbox #(int) mb;
  std::process p;
  semaphore us;
  int v, ok;

  initial begin
    ss = new(1);
    ss.get(1);
    $display("S1 %0d", ss.try_get(1));
    mb = new();
    mb.put(5);
    mb.get(v);
    $display("S2 %0d", v);
    p = std::process::self();
    $display("S3 %0d", p.status() == std::process::RUNNING);
    us = new;
    $display("S4 %0d", us.tag);
    ok = std::randomize(v) with { v inside {[3:3]}; };
    $display("S5 %0d %0d", ok, v);
  end
endmodule
