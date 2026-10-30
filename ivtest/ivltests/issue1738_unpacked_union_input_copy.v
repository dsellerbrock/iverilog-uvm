typedef union { bit [7:0] b; int i; } u_t;

module top;
  u_t u, v;

  function automatic u_t relay(u_t a);
    a.b = 8'h09;
    return a;
  endfunction

  initial begin
    u.b = 8'h86;
    v = relay(u);
    if (u.b !== 8'h86) $fatal(1, "input argument changed caller: %h", u.b);
    if (v.b !== 8'h09) $fatal(1, "function result incorrect: %h", v.b);
    $display("PASS");
  end
endmodule
