module sv_randsequence_nonconstant_actual_fail;
  int source, received, evaluations;

  function automatic int runtime_value();
    evaluations++;
    return source;
  endfunction

  initial begin
    source = 7;
    randsequence (main)
      main : add(runtime_value());
      void add(input logic [3:0] value) : { received = value; };
    endsequence
    if (received != 7 || evaluations != 1)
      $fatal(1, "received=%0d evaluations=%0d", received, evaluations);
    $display("PASS received=%0d evaluations=%0d", received, evaluations);
  end
endmodule
