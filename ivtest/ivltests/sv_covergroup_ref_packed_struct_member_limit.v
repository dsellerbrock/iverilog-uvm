module sv_covergroup_ref_packed_struct_member_limit;
  // IEEE 1800-2017/2023 13.5.2 permits unpacked, not packed, structure members.
  typedef struct packed {
    logic [3:0] field;
  } packed_value_t;

  packed_value_t packed_value;

  covergroup ref_cg(ref logic [3:0] value);
    cp: coverpoint value;
  endgroup

  ref_cg cov;

  initial cov = new(packed_value.field);
endmodule
