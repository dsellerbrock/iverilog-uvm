module sv_randsequence_output_formal_2023;
  int received;
  initial begin
    randsequence (main)
      main : produce(7, received);
      void produce(input int seed, output int value) : { value = seed; };
    endsequence
    if (received != 7) $fatal(1, "received=%0d", received);
    $display("PASS output=%0d", received);
  end
endmodule
