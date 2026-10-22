// IEEE 1800-2017/2023 §24.3.2: program-port updates return to design Active.
module p24_program_port_test;
  logic r;
  wire dw1, dw2;
  int seen = 0;

  assign dw1 = r;
  p24_port_probe p_i(dw2, dw1);

  always @(dw2) begin
    if ((seen == 0 && dw2 !== 1'b0) ||
        (seen == 1 && dw2 !== 1'b1) || seen > 1)
      $fatal(1, "unexpected program-port update %0d: %b", seen, dw2);
    seen++;
    $display("dw2=%b", dw2);
  end

  initial begin
    r = 0;
    #10 r = 1;
    #1;
    if (seen != 2) $fatal(1, "expected two program-port updates, saw %0d", seen);
    $display("PASS program_port_reactive");
    $finish;
  end
endmodule

program p24_port_probe(output pw2, input pw1);
  assign pw2 = pw1;
endprogram
