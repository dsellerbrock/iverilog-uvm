module sv_covergroup_ref_write_fail;
  logic actual;

  covergroup read_cg(ref logic value);
    cp: coverpoint value;
  endgroup

  covergroup ref_cg(ref logic value);
    cp: coverpoint value iff (value++);
  endgroup

  covergroup writable_cg;
    cp: coverpoint actual iff (actual++);
  endgroup

  read_cg read_control;
  ref_cg write_probe;
  writable_cg write_control;
  initial begin
    read_control = new(actual);
    write_probe = new(actual);
    write_control = new;
  end
endmodule
