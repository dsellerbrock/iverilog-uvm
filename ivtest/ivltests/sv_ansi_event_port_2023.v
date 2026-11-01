module sv_ansi_event_listener(input event e);
  initial begin
    @e;
    $display("EVENT");
  end
endmodule

module sv_ansi_event_port;
  event e;
  sv_ansi_event_listener u(e);

  initial begin
    #1 ->e;
    #1;
    $display("PASSED");
  end
endmodule
