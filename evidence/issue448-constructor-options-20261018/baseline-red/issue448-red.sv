module test;
  bit value;
  covergroup cg(int retain) with function sample(bit v);
    option.per_instance = retain;
    cp: coverpoint v { bins zero = {0}; bins one = {1}; }
  endgroup
  cg kept;
  initial begin
    kept = new(1);
    kept.sample(0);
    kept.sample(1);
    kept = null;
    #0;
    $finish;
  end
endmodule
