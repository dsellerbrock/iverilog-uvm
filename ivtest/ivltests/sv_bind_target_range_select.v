// IEEE 1800-2017/2023 23.11: a constant bind select must name an
// elaborated generate/instance-array element, and x/z is not an index.
module bind_range_probe;
endmodule

module bind_range_leaf;
endmodule

module sv_bind_target_range_select;
  for (genvar i = 0; i < 2; i++) begin : lanes
    bind_range_leaf child();
  end
  bind_range_leaf children[3:1]();

  bind lanes[7].child bind_range_probe generate_probe();
  bind children[0] bind_range_probe array_probe();
  bind children[1'bx] bind_range_probe unknown_probe();
endmodule
