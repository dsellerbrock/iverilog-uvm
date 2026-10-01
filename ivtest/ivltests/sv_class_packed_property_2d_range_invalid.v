// A trailing range that can escape its packed dimension must fail closed.
class packed_range_holder;
  logic [1:0][3:0] flags;
  task check();
    logic [1:0] got;
    int base_idx;
    flags = 8'h12;
    got = flags[0][5:4];
    flags[0][5:4] = 2'b11;
    base_idx = 1;
    got = flags[0][base_idx +: 2];
    flags[0][base_idx +: 2] = 2'b11;
  endtask
endclass
module sv_class_packed_property_2d_range_invalid;
  packed_range_holder h;
  initial begin h=new; h.check(); end
endmodule
