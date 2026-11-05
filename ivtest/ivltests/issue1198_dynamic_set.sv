module issue1198_dynamic_set_case #(parameter int BASE = 0)
    (output logic done);
  int value;
  int selected_values[];

  covergroup cg;
    cp: coverpoint value { bins selected[] = selected_values; }
  endgroup

  cg cov;
  initial begin
    selected_values = '{BASE, BASE + 2};
    cov = new;
    selected_values = '{BASE + 100, BASE + 102};
    value = BASE;
    cov.sample();
    value = BASE + 2;
    cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "module array set bins were not frozen at construction");
    done = 1;
  end
endmodule

module issue1198_dynamic_set;
  logic first_done, second_done;
  issue1198_dynamic_set_case #(.BASE(1)) first(first_done);
  issue1198_dynamic_set_case #(.BASE(10)) second(second_done);

  initial begin
    wait (first_done && second_done);
    $display("issue1198_dynamic_set PASS");
  end
endmodule
