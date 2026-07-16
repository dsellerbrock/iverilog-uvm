module top;
  class c;
    int val;
    covergroup cg;
      cp: coverpoint val { bins lo = {[0:7]}; bins hi = {[8:15]}; }
    endgroup
    function new(); cg = new; endfunction
    function void go(int v); val = v; cg.sample(); endfunction
  endclass
  c o;
  initial begin
    o = new;
    o.go(3);
    $m12_cov;
    o.go(12);
    $m12_cov;
  end
endmodule
