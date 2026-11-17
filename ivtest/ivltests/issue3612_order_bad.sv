class B;
  virtual task t(); endtask
endclass
class C extends B;
  function :final :initial int f(); return 1; endfunction
  task :final :extends t(); endtask
endclass
module top; endmodule
