package p;
  class C;
    function new();
      int value = p::missing_type'(1);
    endfunction
  endclass
endpackage : p

module test;
  p::C c = new();
endmodule
