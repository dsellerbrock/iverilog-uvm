module issue1205_covergroup_duplicate_formal_2023;
  covergroup cg(int x) with function sample(int x);
    cp: coverpoint x;
  endgroup
endmodule
