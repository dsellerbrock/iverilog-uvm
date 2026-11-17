module tb;
  typedef int map_t[string];
  map_t a;
  initial begin
    a = '{};
    a = map_t'{};
    a = '{2{}};
  end
endmodule
