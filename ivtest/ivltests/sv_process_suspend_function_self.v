module sv_process_suspend_function_self;
  process p;

  initial begin
    p = process::self();
    fork
      begin
        #1 p.resume();
      end
    join_none
    suspend_self(p);
    $display("RESUMED_AFTER_FUNCTION");
    #1 $finish;
  end

  function void suspend_self(process target);
    target.suspend();
  endfunction
endmodule
