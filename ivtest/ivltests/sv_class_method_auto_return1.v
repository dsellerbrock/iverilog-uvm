class B;
  int tag;
  function new(int t = 0);
    tag = t;
  endfunction
  function int get();
    return tag;
  endfunction
endclass

class A;
  B b;
  function new();
    b = new(5);
  endfunction
  function int via_prop();
    return b.get();
  endfunction
  function int via_local();
    B x;
    x = b;
    return x.get();
  endfunction
endclass

module test;
  initial begin
    A a;
    B x;
    integer p;
    integer l;
    a = new();
    x = a.b;
    p = a.via_prop();
    l = a.via_local();
    if (a.b.tag !== 5 || x.tag !== 5 || p !== 5 || l !== 5) begin
      $display("FAIL a.b.tag=%0d x.tag=%0d p=%0d l=%0d", a.b.tag, x.tag, p, l);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
