module sv_randsequence_value_return;
  int received;

  initial begin
    randsequence (main)
      main : value { received = value; };
      int value : { return 42; };
    endsequence

    if (received != 42)
      $fatal(1, "received=%0d", received);
    $display("PASS value=%0d", received);
  end
endmodule
