module sv_covergroup_ref_write_fail;
  logic actual;

  covergroup ref_cg(ref logic value);
    cp: coverpoint value++;
  endgroup

  ref_cg write_probe;
  initial begin
    actual = 0;
    write_probe = new(actual);
    write_probe.sample();
  end
endmodule
