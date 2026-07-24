// $swrite / $sformat whose TARGET is the enclosing function's return
// variable wrote nothing at all, silently.
//
// The target is an output argument, but a function's return variable cannot
// be handed to a VPI call as a signal (draw_vpi.c falls back for
// signal_is_return_value()), so it went across as a read-only copy on the
// string stack: $swrite's vpi_put_value updated that copy, the call popped
// it, and nothing ever committed it to the return slot. A plain assignment
// to the return variable always worked, so elaboration now rewrites
//     $swrite(f, fmt, args...)   ->   f = $sformatf(fmt, args...)
// which is the same operation through the path that does work.
//
// Found via UVM. uvm_instance_scope() (uvm_misc.svh) does
//     $swrite(uvm_instance_scope, "%m");
//     pos = uvm_instance_scope.len()-1;
//     while (pos && c != "." && c != ":") c = uvm_instance_scope[--pos];
// so an empty result made `pos' start at -1 and the loop never terminated.
// It had been hidden because the only caller reaches it through
// uvm_object::reseed() -> srandom(), and srandom() used to elaborate to an
// empty block -- which discarded its ARGUMENT along with the call. Making
// srandom() real (M3B-5) is what first executed this code.
module m3b5b_swrite_return_var_test;

  int errors = 0;

  // $swrite into the return variable.
  function string via_swrite();
    $swrite(via_swrite, "a=%0d b=%s", 42, "x");
  endfunction

  // $sformat into the return variable (same underlying path).
  function string via_sformat();
    $sformat(via_sformat, "a=%0d b=%s", 42, "x");
  endfunction

  // A local target has always worked -- kept as the control.
  function string via_local();
    string s;
    $swrite(s, "a=%0d b=%s", 42, "x");
    return s;
  endfunction

  // Plain assignment to the return variable -- the other control.
  function string via_assign();
    via_assign = $sformatf("a=%0d b=%s", 42, "x");
  endfunction

  // %m into the return variable: UVM's exact shape, including the
  // backwards walk that an empty string sent into an unbounded loop.
  function string scope_prefix();
    byte c;
    int  pos;
    $swrite(scope_prefix, "%m");
    pos = scope_prefix.len() - 1;
    if (pos < 0) begin
      $display("FAIL %%m into the return variable produced an empty string");
      errors++;
      return "";
    end
    c = scope_prefix[pos];
    while (pos && (c != ".") && (c != ":")) c = scope_prefix[--pos];
    scope_prefix = scope_prefix.substr(0, pos);
  endfunction

  initial begin
    string want = "a=42 b=x";
    string pfx;

    if (via_swrite()  != want) begin
      $display("FAIL $swrite into return variable: '%s'", via_swrite());
      errors++;
    end
    if (via_sformat() != want) begin
      $display("FAIL $sformat into return variable: '%s'", via_sformat());
      errors++;
    end
    if (via_local()   != want) begin
      $display("FAIL $swrite into local: '%s'", via_local());
      errors++;
    end
    if (via_assign()  != want) begin
      $display("FAIL assignment to return variable: '%s'", via_assign());
      errors++;
    end

    // Must terminate, and must end at the hierarchy separator.
    pfx = scope_prefix();
    if (pfx.len() == 0) begin
      $display("FAIL %%m prefix is empty");
      errors++;
    end

    if (errors == 0) $display("PASS m3b5b_swrite_return_var_test");
    $finish(0);
  end
endmodule
