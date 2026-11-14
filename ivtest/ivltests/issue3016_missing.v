interface class api;
  pure virtual function int f();
  pure virtual task t();
endclass
virtual class impl implements api;
endclass
module test; endmodule
