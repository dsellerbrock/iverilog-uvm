class sv_joint_ordered_independent_randc_illegal_leaf;
  randc bit cycle;
  rand bit value;
  constraint illegal_c { solve cycle before value; }
endclass
module sv_joint_ordered_independent_randc_illegal_order_fail;
  sv_joint_ordered_independent_randc_illegal_leaf item;
endmodule
