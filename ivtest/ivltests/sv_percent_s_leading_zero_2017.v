module sv_percent_s_leading_zero_2017;
  initial begin
    if ($sformatf("%s", 32'h00006162) != "ab")
      $fatal(1, "$sformatf(%%s, 32'h00006162) retained leading zero bytes");
    if ($sformatf("%4s", 32'h00006162) != "  ab")
      $fatal(1, "explicit width was not preserved");
    $display("PASSED");
  end
endmodule
