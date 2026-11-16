module top;
  typedef union tagged { int Number; void Empty; } first_t;

  function automatic first_t mk(int v);
    return tagged Number (v);
  endfunction

  function automatic first_t empty();
    return tagged Empty;
  endfunction

  initial begin
    $display("call %p", mk(3));
    $display("calls %p %p %p", mk(-7), empty(), mk(42));
  end
endmodule
