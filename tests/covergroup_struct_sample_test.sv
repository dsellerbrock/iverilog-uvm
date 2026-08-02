// IEEE 1800-2017 19.8.1: a typed covergroup sample formal retains its
// packed-struct type while coverpoint member expressions are elaborated.
package covergroup_struct_sample_pkg;
  typedef struct packed {
    logic [30:0] unused;
    logic active;
  } status_t;
endpackage

interface covergroup_struct_sample_if;
  import covergroup_struct_sample_pkg::*;
  covergroup status_cg with function sample(status_t status);
    cp_active: coverpoint status.active;
  endgroup
  status_cg cg = new;
endinterface

module covergroup_struct_sample_test;
  import covergroup_struct_sample_pkg::*;
  covergroup_struct_sample_if cov();
  status_t status;
  bit [31:0] raw_status;
  initial begin
    status = '0;
    cov.cg.sample(status);
    raw_status = '0;
    raw_status[0] = 1'b1;
    // A sample actual is assignment-compatible with the declared formal.
    // Its own type does not replace the formal type used by coverpoint
    // expressions such as status.active.
    cov.cg.sample(raw_status);
    if (cov.cg.get_coverage() == 100.0)
      $display("PASS: packed-struct covergroup sample formal");
    else
      $display("FAIL: packed-struct covergroup coverage=%0f", cov.cg.get_coverage());
    $finish;
  end
endmodule
