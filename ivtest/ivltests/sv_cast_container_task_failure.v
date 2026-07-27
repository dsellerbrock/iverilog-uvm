// Task-form failed casts into SELECT destinations must diagnose and preserve
// the selected element, just like the scalar destination control.
module main;
  class Base;
    int id;
  endclass
  class Der extends Base;
  endclass
  class Inner;
    Der q[$];
  endclass
  class Outer;
    Inner inn;
  endclass

  Der fixed[2];
  Outer outer;
  Base bad;
  Der keep;

  initial begin
    bad = new;
    keep = new;
    keep.id = 99;
    fixed[0] = keep;
    outer = new;
    outer.inn = new;
    outer.inn.q.push_back(keep);

    $cast(fixed[0], bad);
    $display("after fixed failure: id=%0d", fixed[0].id);

    $cast(outer.inn.q[0], bad);
    $display("after nested failure: id=%0d size=%0d",
             outer.inn.q[0].id, outer.inn.q.size());
    $finish(0);
  end
endmodule
