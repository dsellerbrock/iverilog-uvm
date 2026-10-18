class base_c;
  bit [3:0] a;
  covergroup cg;
    cp: coverpoint a;
  endgroup
endclass

class derived_c extends base_c;
  covergroup extends missing_cg;
  endgroup : missing_cg
endclass

module test;
endmodule
