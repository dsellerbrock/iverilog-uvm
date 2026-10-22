module o4_parameter_at_least;
  parameter int P = 2;
  bit v;
  covergroup cg;
    option.per_instance = 1;
    option.at_least = P;
    cp: coverpoint v { bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new; v = 1; c.sample();
    $display("O4 after_1=%0.2f", c.get_inst_coverage());
    c.sample();
    $display("O4 after_2=%0.2f", c.get_inst_coverage());
  end
endmodule
