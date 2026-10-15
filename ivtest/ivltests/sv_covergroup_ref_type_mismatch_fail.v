module sv_covergroup_ref_type_mismatch_fail;
  logic signed [3:0] signed_actual;
  logic [2:0] narrow_actual;

  covergroup ref_cg(ref logic [3:0] value);
    cp: coverpoint value;
  endgroup

  ref_cg signed_instance;
  ref_cg narrow_instance;

  initial begin
    signed_instance = new(signed_actual);
    narrow_instance = new(narrow_actual);
  end
endmodule
