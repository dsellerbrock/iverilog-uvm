module sv_randsequence_value_return_fail;
  int received;
  initial begin
    randsequence (main)
      main : value { received = value; };
      int value : { return 1; };
    endsequence
    if (received != 1)
      $fatal(1, "received=%0d", received);
    $display("PASS value=%0d", received);
  end
endmodule
