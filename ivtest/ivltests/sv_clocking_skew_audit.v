// M8 clocking audit (IEEE 1800-2017 clause 14): pin the verified skew and
// sampling behaviors that the base audit (sv_clocking_audit) does not cover.
//   * input  #N  samples the input N time units BEFORE the edge (14.4).
//   * output #N  applies a drive N time units AFTER the edge (14.11).
//   * packed integral and packed-struct clockvars sample the preponed value.
//   * clocking through a virtual interface samples correctly.
// Self-checking: prints PASSED only when every check holds.
interface m8_intf(input logic clk);
  logic [7:0] vd;
  clocking cb @(posedge clk); input vd; endclocking
endinterface

module sv_clocking_skew_audit;
  logic clk = 0;
  logic [7:0] d = 8'h10;
  logic [7:0] q = 8'h00;
  typedef struct packed { logic [3:0] x; logic [3:0] y; } s_t;
  s_t st = '{x:4'h1, y:4'h2};
  int errors = 0;

  always #5 clk = ~clk;   // posedges at t=5,15,25,...

  clocking cbin  @(posedge clk); input  #2 dd = d; input st; endclocking
  clocking cbout @(posedge clk); output #3 q; endclocking

  m8_intf intf(clk);

  initial begin
    // ---- input #2 skew: posedge at t=15 samples d at t=13. ----
    #12 d = 8'h20;   // t=12 (3 before the t=15 edge)
    #2  d = 8'h30;   // t=14 (1 before the t=15 edge)
    @(posedge clk);  // t=15
    #1;
    if (cbin.dd !== 8'h20) begin $display("FAIL input#2 dd=%0h exp=20", cbin.dd); errors++; end
    // packed-struct clockvar sampled the preponed value.
    if (cbin.st.x !== 4'h1 || cbin.st.y !== 4'h2)
      begin $display("FAIL packed-struct st=%p", cbin.st); errors++; end
  end

  initial begin
    // ---- output #3 skew: drive issued at an edge applies at edge+3. ----
    @(cbout);          // align to first posedge (t=5)
    cbout.q <= 8'hAA;  // issued at t=5 -> applies at t=8
    #1;                // t=6
    if (q !== 8'h00) begin $display("FAIL output#3 early q=%0h", q); errors++; end
    #3;                // t=9
    if (q !== 8'hAA) begin $display("FAIL output#3 late q=%0h", q); errors++; end
  end

  initial begin
    // ---- clocking through a virtual interface. ----
    virtual m8_intf vi;
    vi = intf;
    intf.vd = 8'h5A;
    @(vi.cb);
    if (vi.cb.vd !== 8'h5A) begin $display("FAIL vif clocking vd=%0h", vi.cb.vd); errors++; end
  end

  initial begin
    #40;
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
