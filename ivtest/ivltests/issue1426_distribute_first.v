module test;
  covergroup filter_first_cg with function sample(input int value);
    cp: coverpoint value { bins p[2] = {[0:5]} with (item % 2 == 0); }
  endgroup

  covergroup distribute_first_cg with function sample(input int value);
    type_option.distribute_first = 1;
    cp: coverpoint value { bins p[2] = {[0:5]} with (item % 2 == 0); }
  endgroup

  filter_first_cg filter_first = new;
  distribute_first_cg distribute_first = new;
  initial begin
    filter_first.sample(0);
    filter_first.sample(2);
    distribute_first.sample(0);
    distribute_first.sample(2);
    if (filter_first.get_inst_coverage() != 100.0
        || distribute_first.get_inst_coverage() != 50.0)
      $fatal(1, "unexpected coverage: filter-first=%0.1f distribute-first=%0.1f",
             filter_first.get_inst_coverage(),
             distribute_first.get_inst_coverage());
    $display("FILTER_FIRST=%0.1f DISTRIBUTE_FIRST=%0.1f",
             filter_first.get_inst_coverage(),
             distribute_first.get_inst_coverage());
  end
endmodule
