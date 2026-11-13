module issue2935_ansi_port_concat_child(
    input wire unused, input .renamed({hi, lo}));
  logic [3:0] hi, lo;
  initial begin
    #1;
    if ({hi, lo} !== 8'ha5)
      $display("FAILED: %02h", {hi, lo});
    else
      $display("PASSED");
  end
endmodule

module issue2935_ansi_port_concat_top;
  issue2935_ansi_port_concat_child child(.unused(1'b0), .renamed(8'ha5));
endmodule
