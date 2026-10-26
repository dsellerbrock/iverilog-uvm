module sv_covergroup_sample_output_formal_fail;
  covergroup cg with function sample(output int x);
    cp: coverpoint x;
  endgroup
endmodule
