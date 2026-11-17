class B;
  virtual task t(); endtask
endclass
class C extends B;
  function :initial :final int f(); return 1; endfunction
  task :extends :final t(); $display("PASS"); endtask
endclass
module top;
  C c;
  initial begin
    c = new;
    if (c.f() != 1) $fatal(1, "wrong result");
    c.t();
  end
endmodule
