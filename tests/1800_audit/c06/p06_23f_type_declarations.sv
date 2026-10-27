module p06_23f;
  int calls=0;
  function int f(); calls++; return 0; endfunction
  logic [3:0] a=1,b=2; bit [12:0] A_bus;
  localparam type T=type(bit[12:0]);
  parameter type bus_t=type(A_bus);
  var type(a+b) c,d;
  var type(f()) z;
  class W #(type TT=int); function int w(); return $bits(TT); endfunction endclass
  W #(type(A_bus)) w1=new;
  initial begin
    c=a+b; d=a+b;
    $display("DECL c=%0d d=%0d zbits=%0d T=%0d bus=%0d W=%0d calls=%0d",$bits(c),$bits(d),$bits(z),$bits(T),$bits(bus_t),w1.w(),calls);
  end
endmodule
