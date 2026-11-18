package issue3735_pkg;
  class outer;
    class item #(parameter int N = 4);
      int value;
      function new(int v); value = v + N; endfunction
    endclass
    class typed_item #(type T = int);
      T value;
      function new(T v); value = v; endfunction
    endclass
    item#(3) a;
    item b;
    item#(.N(5)) c;
    typed_item#(byte) d;
    function new();
      a = new(10); b = new(10); c = new(10); d = new(8'h72);
    endfunction
  endclass

  class parameterized_outer #(parameter int K = 7);
    class item #(parameter int N = K);
      int value;
      function new(int v); value = v + N; endfunction
    endclass
    item a;
    item#(3) b;
    function new(); a = new(10); b = new(10); endfunction
  endclass
endpackage

module issue3735;
  import issue3735_pkg::*;
  outer o;
  parameterized_outer#(9) p;
  initial begin
    o = new;
    p = new;
    if (o.a.value !== 13 || o.b.value !== 14 || o.c.value !== 15 ||
        o.d.value !== 8'h72 || p.a.value !== 19 || p.b.value !== 13)
      $fatal(1, "wrong nested class specialization values");
    $display("PASS");
  end
endmodule
