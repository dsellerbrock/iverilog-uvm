class empty_library;
endclass
class caller #(type LIBTYPE = int);
  function void run(); LIBTYPE::missing_method(); endfunction
endclass
module test;
  caller#(empty_library) obj;
  initial begin obj = new; obj.run(); end
endmodule
