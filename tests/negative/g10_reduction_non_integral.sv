// IEEE 1800-2017 7.12.3: array reduction methods apply to unpacked
// arrays of INTEGRAL values. A real-element queue must be rejected
// with a diagnostic, not silently accepted.
module g10_reduction_non_integral;
  real rq[$];
  real y;
  initial begin
    rq.push_back(1.5);
    y = rq.sum();
    $display("%f", y);
  end
endmodule
