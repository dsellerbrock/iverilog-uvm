class base #(parameter int P = 4);
  localparam int Q = P + 2;
  parameter logic [7:0] BITS = 8'hb4;
endclass
class middle extends base #(7);
  parameter int R = 13;
endclass
class child extends middle;
  parameter int P = 99;
  localparam int Q = 99;
  parameter int R = 99;
  function int sum(); return super.P + super.Q + super.R; endfunction
  function int selected(); return super.BITS[7:4]; endfunction
endclass
class direct extends base;
  function int sum(); return super.P + super.Q; endfunction
endclass
class property_middle extends base;
  int P = 8;
endclass
class property_child extends property_middle;
  function int value(); return super.P; endfunction
endclass
module issue3015_super_parameter;
  child c;
  direct d;
  property_child pc;
  initial begin
    c = new;
    d = new;
    pc = new;
    if (c.sum() != 29 || c.selected() != 11 || d.sum() != 10 || pc.value() != 8)
      $fatal(1, "wrong super parameters: %0d %0d %0d", c.sum(), c.selected(), d.sum());
    $display("PASS");
  end
endmodule
