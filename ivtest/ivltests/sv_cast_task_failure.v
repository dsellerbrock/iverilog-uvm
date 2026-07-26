// M1C-6: `$cast` called as a TASK must report an error when the cast
// fails (IEEE 1800-2017 6.24.2). Called as a function it returns 0 and
// the caller decides what to do; called as a task there is no return
// value, so the failure has to be announced.
//
// It was announced neither way: the class-destination lowering emitted
// an unconditional store and an unconditional success, so a cast
// between unrelated classes silently installed the incompatible handle.
// The function form is covered by sv_cast_class_destination; this file
// pins the task form's diagnostic, and that the destination survives
// the failed cast unchanged.

module main;

  class Base;
    int id;
  endclass

  class Other;                 // unrelated to Base
    int id;
  endclass

  Base  b;
  Other o;

  initial begin
    b = new();
    b.id = 7;
    o = new();
    o.id = 3;

    // Legal: same type. No diagnostic, and the handle lands.
    begin
      Other o2;
      $cast(o2, o);
      $display("compatible task-form cast: id=%0d", (o2 == null) ? -1 : o2.id);
    end

    // Illegal: unrelated classes. 6.24.2 wants an error, and `o' must
    // still be the object it was.
    $cast(o, b);
    $display("after the failed cast: o.id=%0d", (o == null) ? -1 : o.id);

    $finish(0);
  end

endmodule
