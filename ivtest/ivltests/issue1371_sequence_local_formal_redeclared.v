module issue1371_sequence_local_formal_redeclared;
  logic a, b;
  sequence invalid_sequence(local_value);
    bit local_value;
    (a, local_value = 1) ##1 b;
  endsequence
  assert property (@(posedge a) invalid_sequence(1));
endmodule
