module sv_interconnect_scalar_driver(output wire out);
  assign out = 1'b1;
endmodule

module sv_interconnect_scalar_sink(input wire in);
  initial begin
    #1;
    if (in !== 1'b1)
      $fatal(1, "scalar interconnect value mismatch: %b", in);
    $display("PASSED");
  end
endmodule

module sv_interconnect_scalar;
  interconnect link;
  sv_interconnect_scalar_driver driver(link);
  sv_interconnect_scalar_sink sink(link);
endmodule
