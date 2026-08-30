// IEEE 1800-2017/2023 9.4.2: classification of an ordinary event-or list
// must preserve the established shared-wait lowering and must not diagnose a
// rejected special leaf twice.  IEEE 1800-2017/2023 15.5 permits no posedge or
// negedge qualifier on a named event; pin exactly one source error.
module sv_event_list_prepare_static_diag_fail;
  bit valid;
  event named_source;

  initial begin
    @(valid or posedge named_source);
  end
endmodule
