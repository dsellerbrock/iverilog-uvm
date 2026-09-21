module synthesized_ff(
  input  logic [2:0] controls,
  input  logic       data,
  output logic       q
);
  always_ff @(posedge controls[2] or posedge controls[1]) begin
    if (controls[1]) q <= 1'b0;
    else             q <= data;
  end
endmodule

module surviving_event_and_hardware_clock;
  logic [2:0] controls = 3'b000;
  logic data = 1'b0;
  logic q;
  integer pulses = 0;
  integer clock_wakes = 0;

  synthesized_ff dut(controls, data, q);

  // This child remains behavioral under -S. Its marked Boolean event cone
  // must survive while the FF clock gets an ordinary structural clone.
  initial begin
    #1;
    fork
      begin
        @(posedge (controls[0] && controls[1]));
        pulses = pulses + 1;
      end
      begin
        @(posedge controls[2]);
        clock_wakes = clock_wakes + 1;
      end
    join_none
    #1;
    controls[0] = 1'b1;
    controls[1] = 1'b1;
    controls[0] = 1'b0;
    #1;
    if (pulses !== 1 || q !== 1'b0)
      $fatal(1, "event/reset mismatch pulses=%0d q=%b", pulses, q);

    controls[1] = 1'b0;
    data = 1'b1;
    controls[2] = 1'b1;
    #1;
    if (q !== 1'b1 || clock_wakes !== 1)
      $fatal(1, "clock boundary stale q=%b wakes=%0d", q, clock_wakes);

    $display("PASSED surviving event and hardware clock");
    $finish;
  end
endmodule
