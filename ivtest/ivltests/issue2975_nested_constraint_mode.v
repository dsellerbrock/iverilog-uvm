class leaf;
  rand bit value;
  constraint select_one { value == 1; }
endclass

class root;
  leaf child;
  function new(); child = new; endfunction
endclass

module test;
  root a, b;
  initial begin
    a = new;
    b = new;
    if (a.child.select_one.constraint_mode() !== 1)
      $fatal(1, "constraint should initially be active");
    a.child.select_one.constraint_mode(0);
    if (a.child.select_one.constraint_mode() !== 0 ||
        b.child.select_one.constraint_mode() !== 1)
      $fatal(1, "wrong object or constraint mode");
    if (!a.child.randomize() with { value == 0; } || a.child.value != 0)
      $fatal(1, "disabled constraint still active");
    if (b.child.randomize() with { value == 0; })
      $fatal(1, "other object's constraint was disabled");
    a.child.select_one.constraint_mode(1);
    if (a.child.select_one.constraint_mode() !== 1 ||
        a.child.randomize() with { value == 0; })
      $fatal(1, "constraint was not reenabled");
    $display("PASS nested handle constraint_mode");
  end
endmodule
