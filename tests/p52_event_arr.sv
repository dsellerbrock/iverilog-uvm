// G34 probe: event arr[N] declaration and indexed trigger/wait
module p52_event_arr;

  event arr[4];
  int hits;

  initial begin
    hits = 0;
    fork
      begin @(arr[0]); hits++; end
      begin @(arr[1]); hits++; end
    join_none
    #1 -> arr[0];
    #1 -> arr[1];
    #1;
    if (hits == 2)
      $display("PASS");
    else
      $display("FAIL: hits=%0d", hits);
  end

endmodule
