class cfg_a_inner; int pad; int value; endclass
class cfg_a; cfg_a_inner inner; function new(); inner = new; endfunction endclass

class cfg_b_inner; string pad; int value; endclass
class cfg_b; cfg_b_inner inner; function new(); inner = new; endfunction endclass

class base_seq #(type CONFIG_T);
  CONFIG_T cfg;
  function new(CONFIG_T c); cfg = c; endfunction
endclass

class derived_seq #(type CONFIG_T) extends base_seq #(CONFIG_T);
  function new(CONFIG_T c); super.new(c); endfunction
  virtual task set_value(int v); cfg.inner.value = v; endtask
endclass

module test;
  cfg_a ca;
  cfg_b cb;
  derived_seq#(cfg_a) sa;
  derived_seq#(cfg_b) sb;

  initial begin
    ca = new;
    cb = new;
    sa = new(ca);
    sb = new(cb);
    sa.set_value(100);
    sb.set_value(200);
    if (ca.inner.value != 100 || cb.inner.value != 200)
      $fatal(1, "isolation failed between distinct specializations");
    $display("PASSED");
  end
endmodule
