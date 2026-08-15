module deferred_observed_error_args;
  int value = 7;
  int calls = 0;

  function string sample();
    calls += 1;
    return $sformatf("OBS_ERROR VALUE=%0d CALLS=%0d", value, calls);
  endfunction

  initial begin
    assert #0 (0) else $error($sformatf("%s", sample()));
    value = 99;
    $display("SOURCE VALUE=%0d CALLS=%0d", value, calls);
    #1 $display("AFTER VALUE=%0d CALLS=%0d", value, calls);
  end
endmodule
