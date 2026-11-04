module issue2476_value_plusargs_2state;
  bit [7:0] two = 8'h11;
  logic [7:0] four = 8'h11;
  int ok;

  initial begin
    ok = $value$plusargs("TWO=%d", two);
    if (ok != 1 || two !== 8'h00)
      $fatal(1, "2-state destination: ok=%0d value=%b", ok, two);

    ok = $value$plusargs("FOUR=%d", four);
    if (ok != 1 || four !== 8'hxx)
      $fatal(1, "4-state destination: ok=%0d value=%b", ok, four);

    $display("PASSED");
    $finish;
  end
endmodule
