covergroup cov_t with function sample(int a);
  cp_a: coverpoint a;
endgroup
module sv_cov_instance_unknown_option;
  cov_t cg = new;
  initial cg.cp_a.option.no_such_member = 1;
endmodule
