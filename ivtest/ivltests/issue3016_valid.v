interface class api;
  pure virtual function int f();
  pure virtual task t();
endclass
virtual class base;
  pure virtual function int f();
  virtual task t(); endtask
endclass
virtual class impl extends base implements api;
endclass
virtual class local_impl implements api;
  pure virtual function int f();
  pure virtual task t();
endclass
module test;
  initial $display("PASS");
endmodule
