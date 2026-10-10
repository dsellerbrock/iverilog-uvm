localparam logic [3:0] Z_VALUE = 4'hz;

class named_z_constraint;
  rand logic [3:0] en;
  constraint illegal_value { en == Z_VALUE; }
endclass

module main;
  named_z_constraint obj;
  initial begin
    obj = new;
    if (obj.randomize()) $fatal(1, "illegal named Z constraint accepted");
  end
endmodule
