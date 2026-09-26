// Unknown names and inherited functions still cannot be disabled.
class base_seq;
  function int value(); return 1; endfunction
endclass
class derived_seq extends base_seq;
  task stop_missing(); disable no_such_task; endtask
  task stop_function(); disable value; endtask
endclass
module test;
  derived_seq d = new;
endmodule
