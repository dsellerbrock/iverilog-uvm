class K; endclass
class KD extends K; endclass
typedef struct { byte B; int I; } U;
module p07_08_assoc;
  int ak[K]; int au[U]; int a1[string], a2[string];
  K k1, k2; KD kd; U u1, u2, u3;
  function automatic void byval(int x[string]); x["a"] = 100; endfunction
  function automatic void byref(ref int x[string]); x["a"] = 200; endfunction
  initial begin
    k1 = new; k2 = new; kd = new;
    ak[k1] = 1; ak[k2] = 2; ak[kd] = 3; ak[null] = 4;
    $display("A1 %0d %0d %0d %0d %0d", ak.size(), ak[k1], ak[kd], ak.exists(null), ak[null]);
    u1 = '{1, 10}; u2 = '{2, 20}; u3 = '{1, 11}; au[u1] = 5; au[u2] = 6;
    $display("A2 %0d %0d %0d", au.size(), au[u1], au.exists(u3));
    a1 = '{"a":1, "b":2}; a2 = a1; a2["a"] = 9;
    $display("A3 %0d %0d", a1["a"], a2["a"]);
    byval(a1); $display("A4 %0d", a1["a"]);
    byref(a1); $display("A5 %0d", a1["a"]);
  end
endmodule
