module top;
  function int f(input int x);
    f = x;
  endfunction

  task t;
  endtask

  initial begin
    $probe_visibility;
    $finish;
  end
endmodule
