// IEEE 1800-2017/2023 23.6/23.11: a scalar instance cannot be selected,
// and a non-final instance-array component requires an element select.
module bind_shape_probe;
endmodule

module bind_shape_leaf;
endmodule

module bind_shape_middle;
  bind_shape_leaf child();
endmodule

module sv_bind_target_path_shape_fail;
  bind_shape_leaf scalar();
  bind_shape_middle middles[1:0]();

  bind scalar[0] bind_shape_probe scalar_probe();
  bind middles.child bind_shape_probe missing_select_probe();
endmodule
