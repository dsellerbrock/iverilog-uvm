class C;
  bit sample;
  covergroup cg;
    coverpoint sample;
  endgroup
  function new();
    cg = new;
  endfunction
  function void reassign();
    cg = new;
  endfunction
endclass
module top;
  C obj;
  initial begin
    obj = new;
    obj.reassign();
  end
endmodule
