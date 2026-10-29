module issue1442_detect_overlap_transition;
  bit a;
  covergroup cg;
    option.detect_overlap = 1;
    cp: coverpoint a {
      bins forward = (0 => 1);
      bins repeated = (0 => 1);
    }
  endgroup
  cg cov = new;
  initial $finish;
endmodule
