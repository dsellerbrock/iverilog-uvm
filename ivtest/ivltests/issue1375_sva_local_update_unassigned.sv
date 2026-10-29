module issue1375_sva_local_update_unassigned;
  logic clk, a;
  sequence invalid_update;
    int local_value;
    (a, local_value++);
  endsequence
  assert property (@(posedge clk) invalid_update);
endmodule
