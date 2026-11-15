`default_nettype uwire
module issue3396_default_uwire;
  assign w = 1'b1;
  initial begin
    #1;
    if (w !== 1'b1) $fatal(1, "incorrect implicit net value");
    $display("PASS");
  end
endmodule
`default_nettype wire
