module tb;
  bit value;
  covergroup cg with function sample(int sample_value);
    option.distribute_first = 1;
    cp: coverpoint sample_value { bins p[2] = {[0:5]}; }
  endgroup
  cg c = new;
  initial begin c.sample(0); $finish; end
endmodule
