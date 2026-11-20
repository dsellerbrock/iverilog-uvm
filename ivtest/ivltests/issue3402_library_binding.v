module plain_top;
  gate_leaf u();
endmodule

module cfg_top;
  gate_leaf u();
  branch_stub branch();

  initial begin
    #4;
    $display("root: %l");
    $inspect_library_binding;
  end
endmodule

config outer_cfg;
  design work.cfg_top;
  instance cfg_top.u use gateLib.bound_leaf;
  instance cfg_top.branch use gateLib.inner_cfg:config;
endconfig
