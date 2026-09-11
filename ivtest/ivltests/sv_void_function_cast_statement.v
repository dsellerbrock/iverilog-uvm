package void_statement_pkg;
  int seen;
  function automatic void record(input int n); seen += n; endfunction
endpackage
module sv_void_function_cast_statement;
  int calls, arguments;
  function automatic int value(); arguments++; return 7; endfunction
  function automatic void consume(input int n, output int copied, ref int total);
    calls++;
    copied = n + 1;
    total += n;
  endfunction
  function automatic void empty(input int ignored); endfunction
  function automatic int returns_value(); arguments++; return 42; endfunction
  class base;
    int seen;
    virtual function void apply(input int n, output int copied);
      seen = n;
      copied = seen;
    endfunction
  endclass
  class derived extends base;
    function void apply(input int n, output int copied);
      seen = n + 10;
      copied = seen;
    endfunction
  endclass
  initial begin
    int copied, total;
    base b;
    derived d;
    d = new;
    b = d;
    total = 1;
    void'(consume(value(), copied, total));
    if (calls != 1 || arguments != 1 || copied != 8 || total != 8)
      $fatal(1, "call/argument/output/ref effects");
    consume(value(), copied, total);
    if (calls != 2 || arguments != 2 || copied != 8 || total != 15)
      $fatal(1, "direct-call parity");
    void'(empty(value()));
    if (arguments != 3) $fatal(1, "empty function argument effects");
    void'(void_statement_pkg::record(3));
    if (void_statement_pkg::seen != 3) $fatal(1, "package call");
    void'(b.apply(5, copied));
    if (d.seen != 15 || copied != 15) $fatal(1, "virtual dispatch/copyback");
    void'(returns_value());
    if (arguments != 4) $fatal(1, "nonvoid discard control");
    $display("PASSED");
  end
endmodule
