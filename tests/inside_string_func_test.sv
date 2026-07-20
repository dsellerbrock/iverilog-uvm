// Regression for the NetEUFunc::dup_expr typing bug
// (docs/conformance/m7_stress_findings_2026-07-18.md, finding 5):
// lowerings that DUPLICATE a function-call expression (`inside`, dist,
// range compares) rebuilt the call through its constructor, which
// derives the type from the result signal and loses elaboration's
// type upgrade. A string-returning call in `f() inside {"a","b"}`
// then compiled to a vec4 compare against a string-stack result:
// vec4-stack underflow, garbage compare, always false. This is what
// made uvm_reg's backdoor branch (get_rights() inside {"RW","WO"})
// return UVM_NOT_OK and got reg_basic_test mis-diagnosed as
// "needs DPI".

class rights_holder;
  string mode;

  function new(string m);
    mode = m;
  endfunction

  function string get_rights();
    return mode;
  endfunction

  function int unsigned get_num();
    return 7;
  endfunction
endclass

module inside_string_func_test;
  initial begin
    rights_holder rw_h;
    rights_holder ro_h;
    int bad = 0;

    rw_h = new("RW");
    ro_h = new("RO");

    // string function call directly inside a string set
    if (!(rw_h.get_rights() inside {"RW", "WO"})) bad += 1;
    if (ro_h.get_rights() inside {"RW", "WO"}) bad += 1;

    // negated and nested-expression forms
    if (!(rw_h.get_rights() inside {"XX", "RW"})) bad += 1;

    // integral function call inside value and range sets (dup path too)
    if (!(rw_h.get_num() inside {3, 7, 11})) bad += 1;
    if (!(rw_h.get_num() inside {[5:9]})) bad += 1;
    if (rw_h.get_num() inside {[8:20]}) bad += 1;

    if (bad == 0)
      $display("PASS: function-call operands keep their type through inside lowering");
    else
      $display("FAIL: %0d inside-with-function-call checks failed", bad);
    $finish(0);
  end
endmodule
