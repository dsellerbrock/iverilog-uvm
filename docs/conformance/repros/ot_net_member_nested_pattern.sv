// Reproducer: a nested named assignment pattern onto a struct MEMBER
// works procedurally but not through a continuous assign.
//
//   always_comb hw2reg.tpm_cap = '{ rev: '{...}, loc: '{...} };  // accepted
//   assign      hw2reg.tpm_cap = '{ rev: '{...}, loc: '{...} };  // rejected
//
// The net-side l-value resolves the member to a flat vector, so the
// pattern is matched against a bit count ("Packed array assignment
// pattern expects 10 element(s)") and the nested patterns then hit
// "scalar type is not a valid context for assignment pattern".
// The member names have nowhere to bind. IEEE 1800-2017 10.9.2.
//
// Reached in OpenTitan at spi_device.sv:1632 (hw2reg.tpm_cap).
module top;
  typedef struct packed { logic de; logic [3:0] d; } fld_t;
  typedef struct packed { fld_t rev; fld_t loc; } cap_t;
  typedef struct packed { cap_t tpm_cap; logic other; } hw2reg_t;
  hw2reg_t hw2reg;
  assign hw2reg.tpm_cap = '{ rev: '{de:1'b1, d:4'h5}, loc: '{de:1'b0, d:4'hA} };
endmodule
