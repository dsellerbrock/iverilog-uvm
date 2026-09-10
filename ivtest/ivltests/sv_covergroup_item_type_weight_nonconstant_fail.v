module test;
  localparam int arg=3;
  covergroup cg(int arg) with function sample(bit x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { type_option.weight=arg; }
  endgroup
  cg c;
  initial c=new(2);
endmodule
