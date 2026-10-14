module sv_event_triggered_call_args;
  event ev;
  bit result;
  initial result = ev.triggered(1);
endmodule
