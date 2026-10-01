// The omitted default cannot copy a three-word package array into a
// two-word fixed unpacked-array sample formal.
package default_shape_pkg;
  typedef struct packed { logic Z, L, M, C; } flags_t;
  flags_t wrong_flags[0:2];
endpackage

module top;
  import default_shape_pkg::*;
  covergroup cg with function sample(
      default_shape_pkg::flags_t flags[1:0] =
      default_shape_pkg::wrong_flags);
    cp: coverpoint flags[0].C { bins zero = {0}; }
  endgroup
  cg cov;
  initial begin
    cov = new;
    cov.sample();
  end
endmodule
