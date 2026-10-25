module test;
  typedef struct { string k; } K1;
  typedef struct { logic [7:0] a; bit [3:0] b; int c; } r_t;
  K1 m[string];
  r_t z, x, y;

  function automatic r_t mk(int v);
    r_t r;
    r.a = v;
    r.b = v;
    r.c = v;
    return r;
  endfunction

  initial begin
    m["a"] = '{k: "va"};
    m["b"] = '{k: "vb"};
    if (m["a"] != m["b"]) $display("assoc ne");
    if (m["a"] == m["a"]) $display("assoc eq");

    z = mk(9);
    if (z == mk(9)) $display("function eq");
    if (z != mk(8)) $display("function ne");

    x = '{a: 8'hx1, b: 4'h5, c: 32'd7};
    y = x;
    if ((x == y) === 1'bx) $display("logical x");
    if (x === y) $display("case eq");
  end
endmodule
