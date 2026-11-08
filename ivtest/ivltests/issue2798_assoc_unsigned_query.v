module issue2798_assoc_unsigned_query;
  byte unsigned bu[byte unsigned];
  int unsigned iu[int unsigned];
  int si[int];
  byte unsigned key;
  initial begin
    bu[200] = 1;
    bu[7] = 1;
    if (!bu.first(key) || key != 7 || !bu.last(key) || key != 200)
      $fatal(1, "byte unsigned iteration order");
    if ($low(bu) != 7 || $high(bu) != 200)
      $fatal(1, "byte unsigned query: low=%0d high=%0d", $low(bu), $high(bu));

    iu[32'hffff_fff0] = 1;
    iu[3] = 1;
    if ($low(iu) != 3 || $high(iu) !== 32'hffff_fff0)
      $fatal(1, "int unsigned query: low=%0d high=%0d", $low(iu), $high(iu));

    si[-16] = 1;
    si[3] = 1;
    if ($low(si) != -16 || $high(si) != 3)
      $fatal(1, "signed query: low=%0d high=%0d", $low(si), $high(si));

    $display("PASSED");
    $finish;
  end
endmodule
