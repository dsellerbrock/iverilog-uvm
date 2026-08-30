// A dynamic-list classification pass must not elaborate a rejected leaf and
// then elaborate it again during lowering. The missing class property has one
// source error, independent of the valid dynamic sibling that forces splitting.
class event_list_prepare_single_diag_state;
  bit valid;
endclass

module sv_event_list_prepare_single_diag_fail;
  event_list_prepare_single_diag_state state;

  initial begin
    state = new;
    @(state.valid or state.missing);
  end
endmodule
