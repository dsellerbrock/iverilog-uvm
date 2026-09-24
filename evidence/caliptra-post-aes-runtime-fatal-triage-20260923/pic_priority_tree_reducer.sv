// Reduced from pinned Caliptra v2.1.2 el2_pic_ctrl.sv:405-431,539-562.
// PIC_TOTAL_INT_PLUS1=32, PIC_2CYCLE=0 in the pinned integration profile.
module pic_cmp(input logic [3:0] a_priority, b_priority,
               output logic [3:0] out_priority);
  logic a_is_lt_b;
  assign a_is_lt_b = a_priority < b_priority;
  assign out_priority = a_is_lt_b ? b_priority : a_priority;
endmodule

module pic_priority_tree_reducer;
  localparam N = 32;
  localparam L = $clog2(N);
  logic [N-1:0][3:0] input_priority;
  logic [L:0][N+1:0][3:0] level_priority;
  logic [3:0] selected_priority;

`ifdef WHOLE_OUTER
  assign level_priority[0] = {{2*4{1'b0}}, input_priority[N-1:0]};
`else
  assign level_priority[0][N+1:0] = {{2*4{1'b0}}, input_priority[N-1:0]};
`endif
`ifndef NO_TREE
  for (genvar l = 0; l < L; l++) begin : LEVEL
    for (genvar m = 0; m <= N/(2**(l+1)); m++) begin : COMPARE
      if (m == N/(2**(l+1)))
        assign level_priority[l+1][m+1] = '0;
      pic_cmp cmp_l1 (
        .a_priority(level_priority[l][2*m]),
        .b_priority(level_priority[l][2*m+1]),
        .out_priority(level_priority[l+1][m]));
    end
  end
`endif
  assign selected_priority = level_priority[L][0];

  initial begin
    input_priority = '0;
    #1;
    $display("zero path input=%b l0=%b l1=%b l2=%b l3=%b l4=%b l5=%b",
             input_priority[0], level_priority[0][0],
             level_priority[1][0], level_priority[2][0],
             level_priority[3][0], level_priority[4][0],
             level_priority[5][0]);
    if (selected_priority !== 4'h0)
      $fatal(1, "zero priority tree: got %b", selected_priority);
    input_priority[3] = 4'h5;
    #1;
    if (selected_priority !== 4'h5)
      $fatal(1, "single enabled priority: got %b", selected_priority);
    input_priority[17] = 4'hc;
    #1;
    if (selected_priority !== 4'hc)
      $fatal(1, "higher priority tree: got %b", selected_priority);
    $display("PASS priority tree");
    $finish;
  end
endmodule
