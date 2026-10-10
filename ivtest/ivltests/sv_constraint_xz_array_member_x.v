typedef struct packed {
  logic [3:0] en;
} constraint_region_t;

class array_member_x_constraint;
  rand constraint_region_t regions[0:0];
  constraint illegal_value { regions[0].en == 4'hx; }
endclass

module main;
  array_member_x_constraint obj;
  initial begin
    obj = new;
    if (obj.randomize()) $fatal(1, "illegal X constraint accepted");
  end
endmodule
