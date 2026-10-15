module sv_covergroup_ref_write_fail;
  logic actual;

  covergroup read_cg(ref logic value);
    cp: coverpoint value;
  endgroup

  covergroup ref_cg(ref logic value);
    cp: coverpoint value iff (value++);
  endgroup

  read_cg read_control;
  ref_cg write_probe;
  initial begin
    read_control = new(actual);
    write_probe = new(actual);
  end
endmodule
