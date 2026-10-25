module top;
  covergroup cg with function sample(bit [1:0] x);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    cp: coverpoint x { bins b[] = {[0:3]}; }
  endgroup
  cg c1 = new; cg c2 = new;
  int cov, tot;
  real value;
  initial begin
    c1.sample(0); c1.sample(1); c2.sample(1); c2.sample(2);
    value = cg::get_coverage(cov, tot);
    $display("T6 type cg::get_coverage(ref,ref)=%0.2f cov=%0d tot=%0d %s",
             value, cov, tot,
             (value > 74.99 && value < 75.01 && cov == 3 && tot == 4) ? "PASS" : "FAIL");
  end
endmodule
