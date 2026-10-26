class C;
  extern function int f();
endclass

function int C::f();
  return 1;
endfunction

function int C::f();
  return 2;
endfunction

module main;
  C c;
  initial begin
    c = new;
    $display("value=%0d", c.f());
  end
endmodule
