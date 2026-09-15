class caller #(type LIBTYPE = int);
  function void run(); LIBTYPE::add(1); endfunction
endclass
module test;
  caller#(int) obj;
  initial begin obj = new; obj.run(); end
endmodule
