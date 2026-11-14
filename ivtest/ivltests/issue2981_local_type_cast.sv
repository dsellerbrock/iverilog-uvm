package issue2981_types;
  typedef bit signed [3:0] signed_nibble;
endpackage

class issue2981_object;
  typedef bit [1:0] nibble;
  rand bit [3:0] x;
  rand int signed y;
endclass

module main;
  import issue2981_types::*;
  typedef bit [3:0] nibble;
  issue2981_object c;
  int caller_value;
  initial begin
    c = new;
    caller_value = 25;
    if (!c.randomize() with {
      x == local::nibble'(caller_value);
      y == local::signed_nibble'(x);
    } || c.x != 9 || c.y != -7)
      $fatal(1, "local type cast: x=%0d y=%0d", c.x, c.y);
    if (!c.randomize() with {
      x == local::nibble'('1);
      y == issue2981_types::signed_nibble'(x);
    } || c.x != 15 || c.y != -1)
      $fatal(1, "fill/package cast: x=%0d y=%0d", c.x, c.y);
    $display("PASS");
  end
endmodule
