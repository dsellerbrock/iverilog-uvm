localparam logic [3:0] X_VALUE = 4'hx;

class named_x_constraint;
  rand logic [3:0] en;
  constraint illegal_value { en == X_VALUE; }
endclass

module main;
  named_x_constraint obj;
  initial begin
    obj = new;
    if (obj.randomize()) $fatal(1, "illegal named X constraint accepted");
  end
endmodule
