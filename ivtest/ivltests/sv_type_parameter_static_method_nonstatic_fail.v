class instance_library;
  function void add(int value); endfunction
endclass
class caller #(type LIBTYPE = int);
  function void run(); LIBTYPE::add(1); endfunction
endclass
module test;
  caller#(instance_library) obj;
  initial begin obj = new; obj.run(); end
endmodule
