class scalar_x_constraint;
  rand logic [3:0] en;
  constraint illegal_value { en == 4'hx; }
endclass

module main;
  scalar_x_constraint obj;
  initial begin
    obj = new;
    if (obj.randomize()) $fatal(1, "illegal X constraint accepted");
  end
endmodule
