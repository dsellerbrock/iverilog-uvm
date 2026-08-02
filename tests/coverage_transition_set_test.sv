module coverage_transition_set_test;
  class sample_c;
    int value;

    covergroup combined_cg;
      cp: coverpoint value {
        bins any_pair = (0, 1 => 2, 3);
      }
    endgroup

    covergroup split_cg;
      cp: coverpoint value {
        bins each_pair[] = (0, 1 => 2, 3);
      }
    endgroup

    function new;
      combined_cg = new;
      split_cg = new;
    endfunction

    function void sample(int next);
      value = next;
      combined_cg.sample();
      split_cg.sample();
    endfunction
  endclass

  sample_c obj;
  real combined_cov;
  real split_cov;

  initial begin
    obj = new;
    obj.sample(1);
    obj.sample(3);
    combined_cov = obj.combined_cg.get_inst_coverage();
    split_cov = obj.split_cg.get_inst_coverage();
    if (combined_cov != 100.0 || split_cov != 25.0) begin
      $display("FAIL: transition-set coverage combined=%0f split=%0f",
               combined_cov, split_cov);
      $finish(1);
    end
    $display("PASS: transition-bin step sets expand with exact bin identity");
    $finish;
  end
endmodule
