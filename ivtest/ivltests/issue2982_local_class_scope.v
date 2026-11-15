// IEEE 1800-2023 18.7.1: local:: qualifies names in an inline constraint,
// a class scope included (local::Config::value).
class issue2982_Config;
  static const int value = 9;
  static int limit = 20;
endclass

class issue2982_C;
  rand int x, y;
endclass

module issue2982_local_class_scope;
  issue2982_C c;
  int lo = 5;
  initial begin
    c = new;
    if (!c.randomize() with { x == local::issue2982_Config::value; })
      $display("FAILED randomize 1");
    if (c.x != 9) $display("FAILED x=%0d", c.x);
    if (!c.randomize() with { y > local::lo; y < local::issue2982_Config::limit; })
      $display("FAILED randomize 2");
    if (c.y <= 5 || c.y >= 20) $display("FAILED y=%0d", c.y);
    $display("PASSED");
  end
endmodule
