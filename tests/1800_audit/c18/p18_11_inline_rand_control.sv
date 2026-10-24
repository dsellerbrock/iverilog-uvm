// IEEE 1800-2017 §§18.11–18.11.1 / IEEE 1800-2023 §§18.11–18.11.1.
class CA;
  rand byte x, y;
  byte v, w;
  constraint c1 { x < v && y > w; }
  function new();
    x = 1; y = 10; v = 5; w = 2;
  endfunction
endclass

module test;
  initial begin
    CA a = new;

    if (a.randomize(null) !== 1)
      $fatal(1, "randomize(null) failed for satisfied constraints");
    if (a.x !== 1 || a.y !== 10 || a.v !== 5 || a.w !== 2)
      $fatal(1, "randomize(null) modified object values");

    a.x = 20;
    if (a.randomize(null) !== 0)
      $fatal(1, "randomize(null) accepted unsatisfied constraints");

    a.x = 1;
    a.y = 10;
    if (!a.randomize(x))
      $fatal(1, "randomize(x) failed");
    if (a.y !== 10 || a.x >= a.v)
      $fatal(1, "randomize(x) changed omitted y or violated x < v");

    a.x = 2; a.y = 10; a.w = 2;
    if (!a.randomize(v))
      $fatal(1, "randomize(v) failed for non-rand v");
    if (a.v <= a.x)
      $fatal(1, "randomize(v) did not satisfy x < v");

    $display("PASS in-line random variable control clause 18.11");
  end
endmodule
