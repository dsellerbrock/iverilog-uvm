module i2c_fifo_level_ranges_repro;
  covergroup level_cg (int depth) with function sample(int level);
    cp: coverpoint level {
      bins marked[] = {1, 4, 8, 16};
      bins others = {0, [2:3], [5:7], [9:15], [17:depth]};
    }
  endgroup
  level_cg cg;
  initial begin
    cg = new(64);
    cg.sample(1);
    cg.sample(32);
    $display("PASS fifo-level bins %0f", cg.get_coverage());
  end
endmodule
