module top;
  function void f(); process me; me = process::self(); me.suspend(); endfunction
  initial begin f(); $display("REACHED_AFTER_FUNCTION_SUSPEND"); end
endmodule
