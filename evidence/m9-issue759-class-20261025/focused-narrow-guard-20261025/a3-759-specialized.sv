class payload; endclass
class box #(type T=int);
  T item;
  function void f();
    logic q;
    q = item;
  endfunction
endclass
module top;
  box#(payload) b;
  initial b.f();
endmodule
