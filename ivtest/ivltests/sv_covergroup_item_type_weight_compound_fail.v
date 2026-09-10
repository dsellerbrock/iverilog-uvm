module test;
  localparam int arg=3;
  covergroup cg(int arg) with function sample(bit x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x; cy: coverpoint y; xy: cross cx,cy { type_option.weight=arg+0; }
  endgroup
  cg c;
  initial c=new(2);
endmodule
