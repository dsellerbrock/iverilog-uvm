// Method calls through an indexed element of a STATIC unpacked array of
// class handles (or virtual interfaces). The receiver index used to be
// silently DROPPED during method-target elaboration, so `arr[i].method()`
// always evaluated the receiver as word 0 of the array — every call
// dispatched through the first element (a silent miscompile; observed as
// `arr[1].show()` printing element 0's state).
//
// Covers constant and variable indices, methods with side effects on the
// receiver, function methods returning per-element state, and a virtual
// interface array dispatching by element.

module sv_class_array_method_dispatch;

  int errors = 0;

  class Cnt;
    int id;
    int bumps = 0;
    function new(int i); id = i; endfunction
    task bump(); bumps++; endtask
    function int get_id(); return id; endfunction
  endclass

  Cnt arr[3];

  pin_if p0();
  pin_if p1();
  virtual pin_if vps[2];

  task automatic expect_int(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d exp %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    for (int i = 0; i < 3; i++) arr[i] = new(i + 10);

    // Constant index: the receiver must be THAT element.
    expect_int("arr[1].get_id()", arr[1].get_id(), 11);
    expect_int("arr[2].get_id()", arr[2].get_id(), 12);

    // Variable index with side effects: each element bumps itself once.
    for (int i = 0; i < 3; i++) arr[i].bump();
    expect_int("arr[0].bumps", arr[0].bumps, 1);
    expect_int("arr[1].bumps", arr[1].bumps, 1);
    expect_int("arr[2].bumps", arr[2].bumps, 1);

    // Repeat on one element only.
    arr[2].bump();
    expect_int("arr[2].bumps again", arr[2].bumps, 2);
    expect_int("arr[0].bumps unchanged", arr[0].bumps, 1);

    // Virtual-interface array element dispatch.
    vps[0] = p0; vps[1] = p1;
    vps[1].mark();
    expect_int("p1 marked", p1.marks, 1);
    expect_int("p0 not marked", p0.marks, 0);
    for (int i = 0; i < 2; i++) vps[i].mark();
    expect_int("p0 marked once", p0.marks, 1);
    expect_int("p1 marked twice", p1.marks, 2);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule

interface pin_if;
  int marks = 0;
  task mark(); marks++; endtask
endinterface
