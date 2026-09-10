module test;
  localparam int arg=3;
  covergroup cg with function sample(bit x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { type_option.weight=-1; }
  endgroup
  cg c;
  initial c=new;
endmodule
