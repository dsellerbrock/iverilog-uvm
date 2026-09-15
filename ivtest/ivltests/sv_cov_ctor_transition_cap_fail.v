module test;
  covergroup cg(int lo,int hi) with function sample(int value);
    cp: coverpoint value { bins path[] = ([lo:hi] => [lo:hi]); }
  endgroup
  cg c;
  initial begin c=new(0,256); #0; $fatal(1,"excessive transition program accepted"); end
endmodule
