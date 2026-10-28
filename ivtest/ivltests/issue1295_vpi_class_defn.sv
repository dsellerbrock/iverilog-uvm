module top;
  class C;
    int x;
    function void f(); x = 1; endfunction
  endclass
  C obj;
  initial obj = new;
endmodule
