package existing_pkg;
  task caller;
    existing_pkg::missing();
  endtask
endpackage

module test;
  initial existing_pkg::caller();
endmodule
