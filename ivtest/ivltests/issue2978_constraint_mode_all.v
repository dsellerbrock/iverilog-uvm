class Base;
  rand bit x;
  int mode_evaluations;

  function automatic bit one();
    return 1;
  endfunction

  function automatic bit count_mode(bit mode);
    mode_evaluations++;
    return mode;
  endfunction

  function automatic void set_modes(bit mode);
    this.constraint_mode(count_mode(mode));
  endfunction

  constraint base_c { x == one(); }
endclass

class Derived extends Base;
  rand bit y;
  constraint derived_c { y == 1; }
  static constraint shared_c { y == 1; }
endclass

module test;
  Derived obj, other;
  initial begin
    obj = new;
    other = new;
    obj.set_modes(0);
    if (obj.mode_evaluations != 1)
      $fatal(1, "inherited setter must evaluate its argument once");
    if (obj.base_c.constraint_mode() !== 0 ||
        obj.derived_c.constraint_mode() !== 0 ||
        obj.shared_c.constraint_mode() !== 0 ||
        other.base_c.constraint_mode() !== 1 ||
        other.derived_c.constraint_mode() !== 1 ||
        other.shared_c.constraint_mode() !== 0)
      $fatal(1, "object-wide setter did not disable the correct modes");
    if (!obj.randomize() with { x == 0; y == 0; } || {obj.x, obj.y} !== 2'b00)
      $fatal(1, "disabled constraints were enforced");

    obj.constraint_mode(obj.count_mode(1));
    if (obj.mode_evaluations != 2)
      $fatal(1, "object-wide setter must evaluate its argument once");
    if (obj.base_c.constraint_mode() !== 1 ||
        obj.derived_c.constraint_mode() !== 1 ||
        obj.shared_c.constraint_mode() !== 1 ||
        other.shared_c.constraint_mode() !== 1)
      $fatal(1, "object-wide setter did not re-enable constraints");
    if (!obj.randomize() || {obj.x, obj.y} !== 2'b11)
      $fatal(1, "enabled constraints did not force the expected values");

    $display("PASS object-wide constraint_mode");
  end
endmodule
