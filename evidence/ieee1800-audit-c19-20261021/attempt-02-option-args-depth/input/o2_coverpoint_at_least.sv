module o2_coverpoint_at_least;
  bit v;
  covergroup cg(int al);
    option.per_instance = 1;
    cp: coverpoint v { option.at_least = al; bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new(2); v = 1; c.sample();
    $display("O2 after_1=%0.2f", c.get_inst_coverage());
    c.sample();
    $display("O2 after_2=%0.2f", c.get_inst_coverage());
  end
endmodule
