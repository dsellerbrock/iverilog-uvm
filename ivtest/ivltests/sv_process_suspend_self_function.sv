module top;
  process p;
  function void suspend_self();
    p.suspend();
  endfunction

  initial begin
    p = process::self();
    suspend_self();
    $display("PASSED");
  end

  initial begin
    #1;
    p.resume();
  end
endmodule
