class C;
  int id;
  function new(int i);
    id = i;
  endfunction
endclass

typedef bit edges_t[C];

module test;
  edges_t a, b;
  C c;

  initial begin
    c = new(1);
    a[c] = 1'b1;
    b = a;

    if (!b.exists(c) || b[c] !== 1'b1)
      $display("FAIL");
    else
      $display("PASS");
  end
endmodule
