module p35_basic;
  import "DPI-C" function int c_add(int a, int b);
  import "DPI-C" function real c_scale(real x);
  import "DPI-C" function string c_greet(string s);
  import "DPI-C" function void c_out(output int o);
  import "DPI-C" context function int c_call_sv();
  export "DPI-C" function sv_cb;

  function int sv_cb(int x);
    return x * 10;
  endfunction

  int o;
  initial begin
    $display("D1 %0d", c_add(2, 3));
    $display("D2 %0.1f", c_scale(1.5));
    $display("D3 %s", c_greet("bob"));
    c_out(o);
    $display("D4 %0d", o);
    $display("D5 %0d", c_call_sv());
  end
endmodule
