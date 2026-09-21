// Accepted integral full-expression forms supported by the current event path.
module top;
  class cfg_t;
    logic a, b, sel;
  endclass
  cfg_t cfg = new;
  bit arith, concat, ternary, sfunc;
  task automatic wait_arith;   @(cfg.a + cfg.b);                  arith = 1;   endtask
  task automatic wait_concat;  @({cfg.a, cfg.b});                 concat = 1;  endtask
  task automatic wait_ternary; @(cfg.sel ? cfg.a : cfg.b);        ternary = 1; endtask
  task automatic wait_sfunc;   @($countones({cfg.a, cfg.b}));     sfunc = 1;   endtask
  initial begin
    cfg.a = 0; cfg.b = 0; cfg.sel = 1;
    fork
      wait_arith(); wait_concat(); wait_ternary(); wait_sfunc();
    join_none
    #1 cfg.a = 1;
    #1 begin
      if (!arith || !concat || !ternary || !sfunc)
        $fatal(1, "full-expression form did not wake: %b%b%b%b", arith, concat, ternary, sfunc);
      $display("PASS full-expression-forms");
      $finish(0);
    end
  end
endmodule
