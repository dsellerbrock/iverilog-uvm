module sv_covergroup_ref_packed_struct_member_limit;
  // Pin the bounded whole-variable subset; packed-member legality is unqualified.
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
