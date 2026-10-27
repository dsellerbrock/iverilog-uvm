module issue1201_illegal_transition_bins;
  bit [1:0] value;
  covergroup cg;
    cp: coverpoint value {
      illegal_bins bad = (0 => 2);
    }
  endgroup

  cg cov = new;
  initial begin
    value = 0;
    cov.sample();
    value = 2;
    cov.sample();
    $display("illegal_transition_seen");
    $finish;
  end
endmodule
