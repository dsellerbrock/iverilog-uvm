module p19_07_option_args;
  bit [7:0] a;
  covergroup cal(int al);  option.per_instance = 1; option.at_least = al;
    coverpoint a { bins x = {5}; } endgroup
  covergroup cak;          option.per_instance = 1; option.at_least = 3;
    coverpoint a { bins x = {5}; } endgroup
  covergroup cbg(int abm); option.per_instance = 1; option.auto_bin_max = abm;
    coverpoint a; endgroup
  covergroup cbp(int abm); option.per_instance = 1;
    coverpoint a { option.auto_bin_max = abm; } endgroup
  covergroup cbk;          option.per_instance = 1; option.auto_bin_max = 4;
    coverpoint a; endgroup
  cal x1; cak x2; cbg y1; cbp y2; cbk y3;
  initial begin
    x1 = new(3); x2 = new; y1 = new(4); y2 = new(4); y3 = new;
    a = 5; x1.sample(); x1.sample(); x2.sample(); x2.sample();
    $display("ATL_ARG2 %0.2f ATL_LIT2 %0.2f", x1.get_inst_coverage(), x2.get_inst_coverage());
    x1.sample(); x2.sample();
    $display("ATL_ARG3 %0.2f ATL_LIT3 %0.2f", x1.get_inst_coverage(), x2.get_inst_coverage());
    a = 0; y1.sample(); y2.sample(); y3.sample();
    $display("ABM_CG_ARG %0.2f ABM_CP_ARG %0.2f ABM_LIT %0.2f",
             y1.get_inst_coverage(), y2.get_inst_coverage(), y3.get_inst_coverage());
  end
endmodule
