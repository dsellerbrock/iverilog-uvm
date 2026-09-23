module plain_event_triggered_call_crash;
  event ev;
  initial $display("%b", ev.triggered());
endmodule
