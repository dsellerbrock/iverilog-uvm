// IEEE 1800-2017/2023 23.11: bind target instance selects are constant.
module bind_dynamic_probe;
endmodule

module bind_dynamic_leaf;
endmodule

module sv_bind_target_dynamic_select;
  integer selected;

  for (genvar i = 0; i < 2; i++) begin : lanes
    bind_dynamic_leaf child();
  end
  bind_dynamic_leaf children[1:0]();

  bind lanes[selected].child bind_dynamic_probe generate_probe();
  bind children[selected] bind_dynamic_probe array_probe();
endmodule
