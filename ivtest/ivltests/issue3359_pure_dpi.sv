package issue3359_pkg;
  import "DPI-C" pure function int issue3359_abs(input int value);
  function automatic int wrapped(input int value);
    return issue3359_abs(value);
  endfunction
endpackage

class item;
  int state_value;
  rand int x, y, z;
  constraint values {
    y inside {[4:7]};
    x == issue3359_pkg::issue3359_abs(-y);
    z == issue3359_pkg::wrapped(state_value);
  }
endclass

module top;
  item obj;
  initial begin
    obj = new;
    for (int i = 1; i <= 3; i++) begin
      obj.state_value = -i;
      if (!obj.randomize()) $fatal(1, "randomize failed");
      if (obj.x != obj.y || obj.y < 4 || obj.y > 7 || obj.z != i)
        $fatal(1, "wrong values: x=%0d y=%0d z=%0d", obj.x, obj.y, obj.z);
    end
    $display("PASS");
  end
endmodule
