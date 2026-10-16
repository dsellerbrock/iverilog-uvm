// IEEE 1800-2017/2023 13.4.4: a nonblocking event trigger is deferred work.
module sv_function_deferred_event_nb_context_fail;
  event scheduled;
  function integer schedule();
    ->> scheduled;
    schedule = 1;
  endfunction
  wire unused = schedule();
  initial begin #1; $display("UNEXPECTED"); $finish; end
endmodule
