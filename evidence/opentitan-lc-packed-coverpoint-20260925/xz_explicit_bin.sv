module test;
  logic v;
  covergroup cg;
    option.per_instance = 1;
    cp: coverpoint v {
      bins x_value = {1'bx};
      bins z_value = {1'bz};
      bins zero = {1'b0};
      wildcard bins either = {1'b?};
    }
  endgroup
  cg cov;
  initial begin
    cov = new;
    v = 1'bx;
    cov.sample();
    $display("after_x=%f", cov.get_inst_coverage());
    v = 1'bz;
    cov.sample();
    $display("after_z=%f", cov.get_inst_coverage());
    v = 1'b0;
    cov.sample();
    $display("after_0=%f", cov.get_inst_coverage());
  end
endmodule
