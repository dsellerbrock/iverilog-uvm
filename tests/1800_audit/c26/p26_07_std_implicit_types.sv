module p26_07_std_implicit_types;
  semaphore ss;
  mailbox #(int) mb;
  process p;
  int v;

  initial begin
    ss = new(1);
    ss.get(1);
    $display("I1 %0d", ss.try_get(1));
    mb = new();
    mb.put(6);
    mb.get(v);
    $display("I2 %0d", v);
    p = process::self();
    $display("I3 %0d", p.status() == process::RUNNING);
  end
endmodule
