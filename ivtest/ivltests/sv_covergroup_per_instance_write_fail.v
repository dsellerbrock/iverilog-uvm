module test;
  bit value;
  covergroup cg;
    cp: coverpoint value;
  endgroup
  cg item;
  initial begin
    item = new;
    item.option.per_instance = 1;
  end
endmodule
