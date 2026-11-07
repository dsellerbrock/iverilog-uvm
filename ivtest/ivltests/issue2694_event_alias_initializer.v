module tb;
  event source;
  event alias_event = source;

  initial begin
    -> source;
    #0;
    if (!alias_event.triggered)
      $fatal(1, "event declaration alias did not share trigger");
    $display("PASSED");
    $finish;
  end
endmodule
