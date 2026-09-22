// IEEE 1800-2017/2023 16.9.2.1 timing matrix.
// Exact [*0] removes one cycle from a following positive ## delay.
module leading_empty_repeat_boundary_v3;
  bit clk = 0, a = 0;
  bit p_ol1 = 0, p_ol2 = 0, p_nol1 = 0, p_nol2 = 0;
  bit e_ol1 = 0, l_ol1 = 0, e_ol2 = 0, l_ol2 = 0;
  bit e_nol1 = 0, l_nol1 = 0, e_nol2 = 0, l_nol2 = 0;
  bit b_p_ol1 = 0, b_p_ol2 = 0, b_p_nol1 = 0, b_p_nol2 = 0;
  bit b_e_ol1 = 0, b_l_ol1 = 0, b_e_ol2 = 0, b_l_ol2 = 0;
  bit b_e_nol1 = 0, b_l_nol1 = 0, b_e_nol2 = 0, b_l_nol2 = 0;
  int fp_ol1=0, fp_ol2=0, fp_nol1=0, fp_nol2=0;
  int fe_ol1=0, fl_ol1=0, fe_ol2=0, fl_ol2=0;
  int fe_nol1=0, fl_nol1=0, fe_nol2=0, fl_nol2=0;
  always #5 clk = ~clk;

  // Positive: |-> ##1 is same tick; |-> ##2 is next tick.
  assert property (@(posedge clk) p_ol1 |-> a[*0] ##1 b_p_ol1) else fp_ol1++;
  assert property (@(posedge clk) p_ol2 |-> a[*0] ##2 b_p_ol2) else fp_ol2++;
  // Positive: |=> moves the consequent start one tick after the antecedent.
  assert property (@(posedge clk) p_nol1 |=> a[*0] ##1 b_p_nol1) else fp_nol1++;
  assert property (@(posedge clk) p_nol2 |=> a[*0] ##2 b_p_nol2) else fp_nol2++;

  assert property (@(posedge clk) e_ol1 |-> a[*0] ##1 b_e_ol1) else fe_ol1++;
  assert property (@(posedge clk) l_ol1 |-> a[*0] ##1 b_l_ol1) else fl_ol1++;
  assert property (@(posedge clk) e_ol2 |-> a[*0] ##2 b_e_ol2) else fe_ol2++;
  assert property (@(posedge clk) l_ol2 |-> a[*0] ##2 b_l_ol2) else fl_ol2++;
  assert property (@(posedge clk) e_nol1 |=> a[*0] ##1 b_e_nol1) else fe_nol1++;
  assert property (@(posedge clk) l_nol1 |=> a[*0] ##1 b_l_nol1) else fl_nol1++;
  assert property (@(posedge clk) e_nol2 |=> a[*0] ##2 b_e_nol2) else fe_nol2++;
  assert property (@(posedge clk) l_nol2 |=> a[*0] ##2 b_l_nol2) else fl_nol2++;

  task automatic idle; repeat (2) @(negedge clk); endtask
  initial begin
    // Four positive controls.
    @(negedge clk) begin p_ol1=1; b_p_ol1=1; end
    @(negedge clk) begin p_ol1=0; b_p_ol1=0; end idle();
    @(negedge clk) p_ol2=1;
    @(negedge clk) begin p_ol2=0; b_p_ol2=1; end
    @(negedge clk) b_p_ol2=0; idle();
    @(negedge clk) p_nol1=1;
    @(negedge clk) begin p_nol1=0; b_p_nol1=1; end
    @(negedge clk) b_p_nol1=0; idle();
    @(negedge clk) p_nol2=1;
    @(negedge clk) p_nol2=0;
    @(negedge clk) b_p_nol2=1;
    @(negedge clk) b_p_nol2=0; idle();

    // |-> ##1: early means one sample before its same-tick target; late one after.
    @(negedge clk) b_e_ol1=1;
    @(negedge clk) begin b_e_ol1=0; e_ol1=1; end
    @(negedge clk) e_ol1=0; idle();
    @(negedge clk) l_ol1=1;
    @(negedge clk) begin l_ol1=0; b_l_ol1=1; end
    @(negedge clk) b_l_ol1=0; idle();

    // |-> ##2: early is the antecedent tick; late is two ticks after it.
    @(negedge clk) begin e_ol2=1; b_e_ol2=1; end
    @(negedge clk) begin e_ol2=0; b_e_ol2=0; end idle();
    @(negedge clk) l_ol2=1;
    @(negedge clk) l_ol2=0;
    @(negedge clk) begin b_l_ol2=1; end
    @(negedge clk) b_l_ol2=0; idle();

    // |=> ##1 target is one tick after antecedent: pulse on antecedent or two later.
    @(negedge clk) begin e_nol1=1; b_e_nol1=1; end
    @(negedge clk) begin e_nol1=0; b_e_nol1=0; end idle();
    @(negedge clk) l_nol1=1;
    @(negedge clk) l_nol1=0;
    @(negedge clk) begin b_l_nol1=1; end
    @(negedge clk) b_l_nol1=0; idle();

    // |=> ##2 target is two ticks after antecedent: pulse one or three later.
    @(negedge clk) e_nol2=1;
    @(negedge clk) begin e_nol2=0; b_e_nol2=1; end
    @(negedge clk) b_e_nol2=0; idle();
    @(negedge clk) l_nol2=1;
    @(negedge clk) l_nol2=0;
    @(negedge clk);
    @(negedge clk) begin b_l_nol2=1; end
    @(negedge clk) b_l_nol2=0; idle();
    $finish(0);
  end

  final begin
    if (fp_ol1||fp_ol2||fp_nol1||fp_nol2 ||
        fe_ol1!=1||fl_ol1!=1||fe_ol2!=1||fl_ol2!=1 ||
        fe_nol1!=1||fl_nol1!=1||fe_nol2!=1||fl_nol2!=1)
      $fatal(1, "v4 p=%0d/%0d/%0d/%0d e=%0d/%0d/%0d/%0d l=%0d/%0d/%0d/%0d",
             fp_ol1,fp_ol2,fp_nol1,fp_nol2,
             fe_ol1,fe_ol2,fe_nol1,fe_nol2,
             fl_ol1,fl_ol2,fl_nol1,fl_nol2);
    $display("PASS: exact empty repeat timing v4");
  end
endmodule
