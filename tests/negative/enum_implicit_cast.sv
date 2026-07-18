// IEEE 1800-2017 6.19.3: assigning a non-enum integral to an enum
// variable requires an explicit cast. Literals, resolved array elements,
// and resolved function returns must all be rejected (vendored ivtest
// enum_compatibility_fail2/3/4). The placeholder-constant leniency for
// UNRESOLVED UVM macro calls stays.
module enum_implicit_cast;
  typedef enum reg [31:0] { A, B } E;
  E e;
  int ea[2];
  function integer f(); return 1; endfunction
  initial begin
    e = 10;     // error: literal
    e = ea[0];  // error: resolved array element
    e = f();    // error: resolved function return
  end
endmodule
