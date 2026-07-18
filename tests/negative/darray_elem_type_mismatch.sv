// IEEE 1800-2017 7.5: dynamic arrays are assignment compatible only with
// arrays of EQUIVALENT element type. A 2-state/4-state element mismatch
// must be rejected. The fork's parameterized-container leniency once
// waved through ANY queue/darray-to-queue/darray mismatch (vendored
// ivtest sv_darray_assign_fail*, sv_queue_assign_fail*).
module darray_elem_type_mismatch;
  logic [31:0] d1[];
  bit   [31:0] d2[];
  int          q1[$];
  logic [31:0] q2[$];
  initial begin
    d1 = d2;   // error: element types not equivalent
    q2 = q1;   // error: element types not equivalent
  end
endmodule
