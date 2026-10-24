module top;
  covergroup cg with function sample(bit [1:0] x);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    cp: coverpoint x { bins b[] = {[0:3]}; }
  endgroup
  cg c1 = new; cg c2 = new;
  real cg1, cp1, cg2;
  initial begin
    c1.sample(0); c1.sample(1); c2.sample(1); c2.sample(2);
    cg1 = c1.get_inst_coverage();
    cp1 = c1.cp.get_inst_coverage();
    cg2 = c2.get_inst_coverage();
    $display("T5 instance covergroup=%0.2f coverpoint=%0.2f second=%0.2f %s",
             cg1, cp1, cg2,
             (cg1 > 49.99 && cg1 < 50.01 && cp1 > 49.99 && cp1 < 50.01 &&
              cg2 > 49.99 && cg2 < 50.01) ? "PASS" : "FAIL");
  end
endmodule
