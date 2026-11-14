module issue2998_negated_pass;
  bit clk = 0;
  logic a = 0, b = 0, disable_check = 0, unknown = 1'bx;
  integer p = 0, f = 0, delayed_p = 0, delayed_f = 0;
  integer window_p = 0, window_f = 0, repeat_p = 0, repeat_f = 0;
  integer unknown_p = 0, unknown_f = 0;
  integer procedural_p = 0, procedural_f = 0, proc_live_p = 0, proc_live_f = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (disable_check) not (a))
    p++; else f++;
  assert property (@(posedge clk) not (a ##1 b))
    delayed_p++; else delayed_f++;
  assert property (@(posedge clk) not (a ##[1:2] b))
    window_p++; else window_f++;
  assert property (@(posedge clk) not (unknown))
    unknown_p++; else unknown_f++;
  assert property (@(posedge clk) not (a[*2]))
    repeat_p++; else repeat_f++;

  always @(negedge clk)
    assert property (@(posedge clk) disable iff (disable_check) not (a))
      procedural_p++; else procedural_f++;

  always @(negedge clk)
    assert property (@(posedge clk) not (a)) proc_live_p++; else proc_live_f++;

  initial begin
    #10 a = 1;
    #10 b = 1;
    #10 a = 0; b = 0; disable_check = 1;
    #10 a = 1; disable_check = 0;
    #10 a = 0;
    #1;
    if (p != 1 || f != 3 || delayed_p != 3 || delayed_f != 1 ||
        window_p != 3 || window_f != 1 || repeat_p != 3 || repeat_f != 1 ||
        unknown_p != 5 || unknown_f != 0 || procedural_p != 0 || procedural_f != 3 ||
        proc_live_p != 1 || proc_live_f != 3)
      $fatal(1, "counts %0d/%0d delayed %0d/%0d window %0d/%0d repeat %0d/%0d unknown %0d/%0d procedural %0d/%0d live %0d/%0d",
             p, f, delayed_p, delayed_f, window_p, window_f, repeat_p, repeat_f,
             unknown_p, unknown_f, procedural_p, procedural_f, proc_live_p, proc_live_f);
    $display("PASS");
    $finish(0);
  end
endmodule
