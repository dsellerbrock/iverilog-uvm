// Legal, but not yet implemented without violating NBA snapshot/region
// semantics. Keep this residual loud instead of executing it as blocking.
class nba_dynamic_holder;
  logic [7:0] value;
endclass

module sv_nba_property_dynamic_fail;
  nba_dynamic_holder obj;
  int idx;
  initial begin
    obj = new;
    obj.value[idx] <= 1'b1;
  end
endmodule
