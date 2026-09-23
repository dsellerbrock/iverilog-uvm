module sv_named_event_triggered_mixed_unsupported;
  event e;
  initial begin
    @(e.triggered or e);
    $fatal(1, "mixed triggered-property sensitivity was silently accepted");
  end
endmodule
