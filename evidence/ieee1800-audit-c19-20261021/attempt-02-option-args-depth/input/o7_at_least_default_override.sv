module o7_at_least_default_override;
  bit a, b;
  covergroup cg;
    option.per_instance = 1;
    option.at_least = 2;
    cpA: coverpoint a { bins hit = {1}; }
    cpB: coverpoint b { option.at_least = 1; bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new; a = 1; b = 1; c.sample();
    $display("O7 cpA=%0.2f cpB=%0.2f", c.cpA.get_inst_coverage(), c.cpB.get_inst_coverage());
  end
endmodule
