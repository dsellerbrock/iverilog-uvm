// IEEE 1800-2017/2023 13.4.4: an immediate -> trigger does not schedule a
// background event that waits until after the function returns.
module sv_function_immediate_event_contassign_ok;
  event immediate_event;
  function integer fire();
    -> immediate_event;
    fire = 1;
  endfunction
  wire result = fire();
  initial begin
    #1;
    if (result != 1) $fatal(1, "FAIL result=%0d", result);
    $display("PASS");
  end
endmodule
