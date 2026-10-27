module o3_expression_at_least;
  bit v;
  covergroup cg(int al);
    option.per_instance = 1;
    option.at_least = al + 1;
    cp: coverpoint v { bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new(1); v = 1; c.sample();
    $display("O3 after_1=%0.2f", c.get_inst_coverage());
    c.sample();
    $display("O3 after_2=%0.2f", c.get_inst_coverage());
  end
endmodule
