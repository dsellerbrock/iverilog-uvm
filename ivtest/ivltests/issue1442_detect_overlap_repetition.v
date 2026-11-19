module issue1442_detect_overlap_repetition;
  covergroup cg with function sample(bit signed [3:0] value);
    option.detect_overlap = 1;
    option.per_instance = 1;

    duplicates: coverpoint value {
      bins first = (0[*2] => 1);
      bins second = (0[*2] => 1);
    }
    explicit_sequence: coverpoint value {
      bins expanded = (0 => 0 => 1);
      bins repeated = (0[*2] => 1);
    }
    ranged: coverpoint value {
      bins variable_length = ([-1:0][*2:4] => 1);
      bins expanded = (-1 => 0 => -1 => 1);
    }
    alternatives: coverpoint value {
      bins mixed = (3[*2] => 2), (0 => 1), (2 => 1);
      bins plain = (0 => 1), (2 => 1);
    }

    disjoint_values: coverpoint value {
      bins low = ([0:1][*2:3] => 4);
      bins high = ([2:3][*2:3] => 4);
    }
    disjoint_lengths: coverpoint value {
      bins shorter = (0[*2:3] => 1);
      bins longer = (0[*4:5] => 1);
    }
    disabled: coverpoint value {
      option.detect_overlap = 0;
      bins first = (0[*2] => 1);
      bins second = (0[*2] => 1);
    }
    long_repetition: coverpoint value {
      bins one_run = (0[*1:65536] => 1);
      bins two_runs = (0[*32768] => 0[*32768] => 1);
    }
  endgroup

  cg cov = new;
  initial begin
    cov.sample(0);
    cov.sample(0);
    if (cov.duplicates.get_inst_coverage() != 0.0)
      $fatal(1, "Incomplete sequence counted");
    cov.sample(1);
    if (cov.duplicates.get_inst_coverage() != 100.0)
      $fatal(1, "Expected both duplicate bins to count the completed sequence");
    $display("PASSED");
  end
endmodule
