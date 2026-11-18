module issue3738;
  logic [47:0] f;
  string t;
  integer calls = 0;

  function automatic logic [47:0] fn(input logic [47:0] v);
    calls = calls + 1;
    return v;
  endfunction
  function logic [47:0] static_fn(input logic [47:0] v);
    return v;
  endfunction
  function automatic logic [11:0] short_fn();
    return 12'h041;
  endfunction
  function automatic string str_fn();
    return "str";
  endfunction
  task automatic check(input string actual, input string expected);
    if (actual != expected || actual.len() != expected.len()) begin
      $display("FAIL: [%s] expected [%s]", actual, expected);
      $finish(1);
    end
  endtask
  initial begin
    f = "v=%0d!";
    t = string'(fn(f));
    check(t, "v=%0d!");
    t = string'({"call=", fn(f)});
    check(t, "call=v=%0d!");
    t = string'({fn(f), "-tail-pad"});
    check(t, "v=%0d!-tail-pad");
    t = string'({fn(f), static_fn(f)});
    check(t, "v=%0d!v=%0d!");
    check(string'(short_fn()), "A");
    check(string'(fn(48'h410042000043)), "ABC");
    check(str_fn(), "str");
    check("\200", "\200");
    if (calls != 5) begin
      $display("FAIL: calls=%0d", calls);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
