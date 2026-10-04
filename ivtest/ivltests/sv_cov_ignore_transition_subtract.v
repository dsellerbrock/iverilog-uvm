// IEEE 1800-2017/2023 19.5.7: a transition sequence named by ignore_bins is
// removed from the other transition bins of the coverpoint. (1=>3) matches the
// set-valued cd bin but must not count; (2=>3) still does. OpenTitan i2c's
// cp_target_read_ack_nack uses this shape.
module test;
  covergroup cg with function sample(bit [3:0] v);
    option.per_instance = 1;
    cp: coverpoint v {
      bins ab = (1 => 2);
      bins cd = ([1:2] => [3:4]);
      ignore_bins ig = (1 => 3);
    }
  endgroup
  cg c = new;
  real cov;
  initial begin
    c.sample(1); c.sample(3);
    cov = c.get_inst_coverage();
    if (cov != 0.0) $fatal(1, "ignored (1=>3) was counted: %f", cov);
    c.sample(2); c.sample(4);
    cov = c.get_inst_coverage();
    if (cov != 50.0) $fatal(1, "(2=>4) was not counted: %f", cov);
    c.sample(1); c.sample(2);
    cov = c.get_inst_coverage();
    if (cov != 100.0) $fatal(1, "(1=>2) was not counted: %f", cov);
    $display("PASSED");
  end
endmodule
