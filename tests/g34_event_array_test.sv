module top;
  event arr[4];
  int cnt;

  initial begin
    fork
      begin @(arr[0]); cnt++; end
      begin @(arr[1]); cnt++; end
      begin @(arr[2]); cnt++; end
      begin @(arr[3]); cnt++; end
    join_none

    #1;
    -> arr[0];
    -> arr[2];
    #1;

    if (cnt != 2) begin
      $display("FAIL cnt=%0d expected=2", cnt);
      $finish;
    end

    -> arr[1]; -> arr[3];
    #1;
    if (cnt != 4) begin
      $display("FAIL cnt=%0d expected=4", cnt);
      $finish;
    end

    $display("PASS event_array");
    $finish;
  end
endmodule
