module o1_group_at_least;
  bit v;
  covergroup cg(int al);
    option.per_instance = 1;
    option.at_least = al;
    cp: coverpoint v { bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new(2); v = 1; c.sample();
    $display("O1 after_1=%0.2f", c.get_inst_coverage());
    c.sample();
    $display("O1 after_2=%0.2f", c.get_inst_coverage());
  end
endmodule
