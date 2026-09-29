class child_cfg;
  rand bit zero, delay;
  constraint order_c { delay == zero; }
endclass
class parent_cfg;
  rand int unsigned clk;
  rand child_cfg child;
  function new; child = new; endfunction
  constraint frequency { clk dist {[48:50] :/ 2}; clk == 50; }
endclass
module reducer;
  parent_cfg cfg = new;
  initial begin
    if (!cfg.randomize()) $fatal(1, "unexpected randomize failure");
    $display("PASS clk=%0d", cfg.clk);
  end
endmodule
