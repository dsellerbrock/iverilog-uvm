module dff(q, d, clear, preset, clock);
  output q; input d, clear, preset, clock; logic q;
  always @(clear or preset)
    if (!clear) assign q = 0; else if (!preset) assign q = 1; else deassign q;
  always @(posedge clock) q = d;
endmodule
module p10_06a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  logic clk = 0, dd = 0, clr = 1, pre = 1;  wire qq;  dff u(qq, dd, clr, pre, clk);
  logic fa, fb, r;  wire nw;  assign nw = 1'b0;
  initial begin
    #1 clr = 0;           #1 ck("assign_clear", qq === 1'b0);
    dd = 1; clk = 1;      #1 ck("assign_blocks_posedge", qq === 1'b0);  clk = 0;
    clr = 1;              #1 ck("deassign_keeps", qq === 1'b0);
    clk = 1;              #1 ck("posedge_after_deassign", qq === 1'b1);  clk = 0;
    dd = 0; pre = 0;      #1 ck("assign_preset", qq === 1'b1);
    clk = 1;              #1 ck("preset_blocks_posedge", qq === 1'b1);  clk = 0;
    pre = 1;              #1 clk = 1;  #1 ck("deassign_then_load", qq === 1'b0);
    fb = 0; force fa = fb; fb = 1;  #1 ck("force_reeval_1", fa === 1'b1);
    fb = 0;               #1 ck("force_reeval_0", fa === 1'b0);
    release fa; fb = 1;   #1 ck("release_holds", fa === 1'b0);
    r = 0; force r = 1; r = 0;  #1 ck("force_overrides_proc", r === 1'b1);
    release r;            #1 ck("release_keeps", r === 1'b1);
    r = 0;                #1 ck("assign_after_release", r === 1'b0);
    force nw = 1;         #1 ck("force_net", nw === 1'b1);
    release nw;           #1 ck("release_net", nw === 1'b0);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
