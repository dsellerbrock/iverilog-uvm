// IEEE 1800-2017 6.18: a nearer non-type declaration shadows an outer
// type name. Reduced from OpenTitan xbar_env_cov.sv:
//   max_delay_cg_obj max_delay_cg_obj[string];
//   max_delay_cg_obj[name] = new({"host_max_delay_", name, "_cg"});
class W;
  string nm;
  function new(string s = "");
    nm = s;
  endfunction
endclass

class E;
  W W[string];
  function void fill(string n);
    W[n] = new({"x_", n});
  endfunction
endclass

module main;
  initial begin
    E e = new;
    e.fill("a");
    e.fill("b");
    if (e.W["a"].nm != "x_a") begin $display("FAILED a=%s", e.W["a"].nm); $finish; end
    if (e.W["b"].nm != "x_b") begin $display("FAILED b=%s", e.W["b"].nm); $finish; end
    $display("PASSED");
  end
endmodule
