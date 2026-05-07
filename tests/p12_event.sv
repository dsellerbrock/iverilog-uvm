// G08 probe: event.triggered race — both wait(e.triggered) and @(e) wake
module p12_event;

  event e;
  int hits;

  initial begin
    hits = 0;
    fork
      begin wait(e.triggered); hits++; end
      begin @(e);              hits++; end
    join_none
    #1 -> e;
    #1;
    if (hits == 2)
      $display("PASS");
    else
      $display("FAIL: hits=%0d", hits);
  end

endmodule
