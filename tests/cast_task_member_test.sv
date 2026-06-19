// Regression: task-form $cast(member, src) into a class property.
//
// The statement form `$cast(this.member, src)` went through the generic VPI
// path, which passed the containing object (`this`) as the destination, so the
// runtime cast checked the ENCLOSING class type instead of the property's type
// and left the member null.  This is the OpenTitan UVM driver idiom
// `$cast(rsp, req.clone())` where rsp is an inherited class member, which
// surfaced as UVM_FATAL [SQRPUT] "Driver put a null response".
//
// The function form and casts into locals always worked; only the task form
// into a property was broken.  This test exercises all three forms plus a
// type-parameter-typed member (mirrors uvm_driver's REQ/RSP chain).

module top;

  class base;
  endclass

  class item extends base;
    int data;
  endclass

  class holder #(type T = base);
    T member;                                  // type-parameter-typed member
    function void cast_task(base src); $cast(member, src); endfunction
    function int  cast_func(base src); return $cast(member, src); endfunction
    function void cast_local(base src); item loc; $cast(loc, src); member = loc; endfunction
  endclass

  initial begin
    base b;
    item it;
    holder #(item) h;
    int errors = 0;

    it = new(); it.data = 42; b = it;
    h = new();

    h.cast_task(b);
    if (h.member == null || h.member.data != 42) begin
      $display("FAIL: task-form $cast into member"); errors++;
    end
    h.member = null;

    void'(h.cast_func(b));
    if (h.member == null || h.member.data != 42) begin
      $display("FAIL: func-form $cast into member"); errors++;
    end
    h.member = null;

    h.cast_local(b);
    if (h.member == null || h.member.data != 42) begin
      $display("FAIL: task-form $cast into local"); errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("cast_task_member_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
