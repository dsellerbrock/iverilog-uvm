module o6_goal_readback;
  bit v;
  covergroup cg(int al);
    option.per_instance = 1;
    option.goal = al * 10;
    cp: coverpoint v { bins hit = {1}; }
  endgroup
  cg c;
  initial begin
    c = new(9);
    $display("O6 goal=%0d", c.option.goal);
  end
endmodule
