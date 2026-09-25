// IEEE 1800-2017 8.25 control: a later formal's packed width depends on W.
// This currently stops during type binding, before specialization keying.
module sv_class_multi_value_dependent_width_fail_2017;
  class box #(int W = 8, logic [W-1:0] Value = 0);
  endclass
  box#(16, 16'h00ff) a;
  box#(16, 16'h01ff) b;
endmodule
