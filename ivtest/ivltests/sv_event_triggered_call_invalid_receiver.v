module sv_event_triggered_call_invalid_receiver;
  bit value;
  bit result;
  initial result = value.triggered();
endmodule
