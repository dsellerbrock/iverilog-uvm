module m #(parameter integer ID = 0);
  export "DPI-C" function getid;
  function int getid();
    return ID;
  endfunction
endmodule

module tb;
  m #(.ID(1)) u1();
  m #(.ID(2)) u2();

  import "DPI-C" context function void c_pick();
  initial c_pick();
endmodule
