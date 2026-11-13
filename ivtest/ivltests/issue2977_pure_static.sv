virtual class base_t; rand bit x; pure static constraint c; endclass
class derived_t extends base_t; static constraint c { x == 1; } endclass
module top;
  derived_t a, b;
  initial begin
    a = new; b = new;
    a.c.constraint_mode(0);
    if (b.c.constraint_mode() != 0) $fatal(1, "static inherited mode not shared");
    if (!b.randomize() with { x == 0; }) $fatal(1, "disabled constraint active");
    b.c.constraint_mode(1);
    if (!a.randomize() || a.x != 1) $fatal(1, "enabled constraint not active");
    $display("PASS pure static override shares mode");
  end
endmodule
