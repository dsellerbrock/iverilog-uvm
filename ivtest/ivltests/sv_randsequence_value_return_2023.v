module sv_randsequence_value_return_2023;
  int received;
  int received_pair;
  initial begin
    randsequence (main)
      main : value { received = value; };
      int value : { return 42; };
    endsequence
    if (received != 42) $fatal(1, "received=%0d", received);
    randsequence (pair)
      pair : value value { received_pair = value[1] + value[2]; };
      int value : { return 21; };
    endsequence
    if (received_pair != 42) $fatal(1, "received_pair=%0d", received_pair);
    $display("PASS value=%0d pair=%0d", received, received_pair);
  end
endmodule
