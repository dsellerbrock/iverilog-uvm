class C;
  int v;
  function void inc(); v++; endfunction
endclass
module tb;
  C m[string];
  initial begin
    m["x"] = new;
    m["x"].v = 5;
    m["x"].inc();
    $display("A4 %0d", m["x"].v);
  end
endmodule
