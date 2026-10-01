// A virtual interface handle reaches a member of a nested interface instance
// (vif.child.sig); waits on that member must work for any edge and in event
// lists with other terms (IEEE 1800-2017/2023 25.9, 9.4.2). They were
// accepted and then never woke: only the child's clocking tick was supported
// (OpenTitan chip `@(cfg.chip_vif.cpu_clk_rst_if.cbn or negedge
// cfg.chip_vif.cpu_clk_rst_if.rst_n)`). A clocking event inside a longer
// event list was skipped with a warning.
interface child_if(input logic clk);
  logic rst_n = 1;
  logic [7:0] d = 0;
  clocking cbn @(negedge clk); input d; endclocking
endinterface

interface outer_if(input logic clk);
  child_if sub(clk);
  logic top_d = 0;
endinterface

class cfg_c;
  virtual outer_if vif;
endclass

class watcher;
  cfg_c cfg;
  int any_rst, neg_rst, pos_rst, any_d, mixed_cb, mixed_edge, clk_edges, list_both;
  task start();
    fork
      forever begin @(cfg.vif.sub.rst_n); any_rst++; end
      forever begin @(negedge cfg.vif.sub.rst_n); neg_rst++; end
      forever begin @(posedge cfg.vif.sub.rst_n); pos_rst++; end
      forever begin @(cfg.vif.sub.d); any_d++; end
      forever begin @(posedge cfg.vif.sub.clk); clk_edges++; end
      forever begin
        @(cfg.vif.sub.cbn or negedge cfg.vif.sub.rst_n);
        mixed_edge++;
      end
      forever begin @(cfg.vif.sub.cbn); mixed_cb++; end
      forever begin @(cfg.vif.sub.d or cfg.vif.top_d); list_both++; end
    join_none
  endtask
endclass

module main;
  int errors;
  logic clk = 0;
  always #5 clk = ~clk;
  outer_if o(clk);
  watcher w;

  task automatic check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    w = new;
    w.cfg = new;
    w.cfg.vif = o;
    w.start();
    #1;
    // Toggles at 8, 15 and 22 (rst_n 1->0, 0->1, 1->0; d 1, 2, 3; top_d too);
    // the run ends at 122: 12 clock posedges (5..115) and 12 negedges (10..120).
    repeat (3) begin
      #7;
      o.sub.rst_n = ~o.sub.rst_n;
      o.sub.d = o.sub.d + 1;
      o.top_d = ~o.top_d;
    end
    #100;
    check("any change of rst_n", w.any_rst, 3);
    check("negedge rst_n", w.neg_rst, 2);
    check("posedge rst_n", w.pos_rst, 1);
    check("any change of d", w.any_d, 3);
    check("posedge of the child clock port", w.clk_edges, 12);
    check("clocking event alone", w.mixed_cb, 12);
    check("clocking event or negedge rst_n", w.mixed_edge, 12 + 2);
    // d and top_d change in the same time step: one wake per step.
    check("d or top_d", w.list_both, 3);
    if (errors == 0) $display("PASSED");
    $finish(0);
  end
endmodule
