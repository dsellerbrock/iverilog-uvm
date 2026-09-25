// IEEE 1800-2023 parameterized class identity: unequal packed values differ.
class mvi_box #(int Width = 16, logic [15:0] Value = 0);
endclass
module sv_class_multi_value_identity_fail_2023;
  mvi_box#(16, 16'h01ff) unequal_target;
  initial unequal_target = mvi_box#(16, 16'h00ff)::new;
endmodule
