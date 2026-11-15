// IEEE 1800-2023 25.7.3 / A.1.6: `extern task name(...);` in an interface is
// a prototype; the one module that defines the task through a connected
// interface port supplies the body. Only `extern forkjoin task` was accepted.
interface fb;
  int n = 0;
  extern task inc();
  extern task add(input int amount, output int total);
  modport slave(ref n, export inc, export add);

  // The interface itself may call its extern task.
  initial #1 inc();
endinterface

module mem(fb.slave a);
  task a.inc();
    a.n += 3;
  endtask
  task a.add(input int amount, output int total);
    a.n += amount;
    total = a.n;
  endtask
endmodule

module top;
  fb i();
  mem m(i.slave);
  int total;
  initial begin
    #2;
    if (i.n !== 3) begin
      $display("FAILED: n = %0d after inc()", i.n);
      $finish;
    end
    i.add(4, total);
    if (i.n !== 7 || total !== 7) begin
      $display("FAILED: n = %0d total = %0d after add(4)", i.n, total);
      $finish;
    end
    $display("PASSED");
  end
endmodule
