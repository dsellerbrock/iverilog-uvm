// IEEE 1800-2023 17.8: input-only and const ref functions stay legal in the
// right-hand side of a checker variable assignment, and the restriction
// does not reach the body of a function the checker declares.
checker c(input bit a, output bit z);
  bit seen, comb_value;
  function automatic bit f_out(input bit x, output bit y);
    y = x;
    return x;
  endfunction
  function automatic bit pure_fn(input bit x);
    bit tmp, copy;
    tmp = f_out(x, copy);   // a procedural statement in a function body
    return tmp & copy;
  endfunction
  function automatic bit by_ref(const ref bit x);
    return x;
  endfunction
  always_comb seen = pure_fn(a);
  always_comb comb_value = by_ref(seen);
  assign z = comb_value;
endchecker

module top;
  bit a = 1, z;
  c ci(a, z);
  initial begin
    #1;
    if (z === 1'b1) $display("PASSED");
    else $display("FAILED: z=%b", z);
  end
endmodule
