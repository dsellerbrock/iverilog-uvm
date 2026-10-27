module top;
  covergroup cg with function sample(bit [1:0] x);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    cp: coverpoint x { bins b[] = {[0:3]}; }
  endgroup
  cg c1 = new; cg c2 = new;
  int cov, tot;
  real value, counted;
  initial begin
    c1.sample(0); c1.sample(1); c2.sample(1); c2.sample(2);
    value = c1.get_coverage();
    counted = c1.get_coverage(cov, tot);
    $display("T3 instance handle type coverage=%0.2f %s; ref=%0.2f cov=%0d tot=%0d",
             value, (value > 74.99 && value < 75.01) ? "PASS" : "FAIL",
             counted, cov, tot);
  end
endmodule
