module test;
  localparam int arg=3;
  covergroup cg with function sample(bit x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x; cy: coverpoint y; xy: cross cx,cy { type_option.weight=32'h80000000; }
  endgroup
  cg c;
  initial c=new;
endmodule
