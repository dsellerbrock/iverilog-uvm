module sv_packed_continuous_bit_dag_overlap_fail;
  logic [2:0] tree;
  assign tree[0] = 1'b0;
  assign tree[1] = tree[0];
  assign tree[0] = 1'b1;
endmodule
