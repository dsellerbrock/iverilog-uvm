module o5_coverpoint_weight;
  bit a, b;
  covergroup cg(int w);
    option.per_instance = 1;
    cp1: coverpoint a { option.weight = w; bins hit = {1}; }
    cp2: coverpoint b { option.weight = 1; bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new(3); a = 1; b = 0; c.sample();
    $display("O5 group=%0.2f cp1=%0.2f cp2=%0.2f", c.get_inst_coverage(), c.cp1.get_inst_coverage(), c.cp2.get_inst_coverage());
  end
endmodule
