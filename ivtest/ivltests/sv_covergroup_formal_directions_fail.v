module sv_covergroup_formal_directions_fail;
  int observed;

  covergroup output_cg(output int value);
    cp: coverpoint value;
  endgroup

  covergroup inout_cg(inout int value);
    cp: coverpoint value;
  endgroup

  output_cg output_instance;
  inout_cg inout_instance;
endmodule
