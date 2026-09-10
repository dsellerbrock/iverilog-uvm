module test;
  localparam int arg=3;
  covergroup cg(int arg) with function sample(bit x);
    cx: coverpoint x { type_option.weight=arg+0; }
  endgroup
  cg c;
  initial c=new(2);
endmodule
