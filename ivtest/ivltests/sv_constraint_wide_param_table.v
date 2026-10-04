// IEEE 1800-2017/2023 18.3, 11.4.5, 7.8: constraints over values wider than 64
// bits. A 66-bit packed struct is a rand dynamic-array element and a rand scalar
// property; it is compared against a wide literal, against a parameter-array
// element selected by a constant or by the foreach index, and against another
// wide property. The parameter-array selection refused anything over 64 bits and a
// wide struct property was silently given a 32-bit solver variable.
typedef struct packed { bit cond; int min_v; int max_v; bit en; } w_t;      // 66 bits
module t;
  localparam w_t DEF [3] = '{'{cond: 1'b0, min_v: 5, max_v: 99, en: 1'b1},
                             '{cond: 1'b1, min_v: -3, max_v: 7, en: 1'b0},
                             '{cond: 1'b0, min_v: 100, max_v: 200, en: 1'b1}};
  class k_lit; rand w_t f[]; constraint c { f.size == 2; f[0] == 66'h2_0000_0005_0000_0063 ; f[1] != f[0]; } endclass
  class k_par; rand w_t f[]; constraint c { f.size == 3; foreach (f[i]) f[i] == DEF[i]; } endclass
  class k_one; rand w_t v; constraint c { v == DEF[1]; } endclass
  class k_cmp; rand w_t v, u; constraint c { v == u; v.min_v inside {[1:9]}; } endclass
  initial begin
    k_lit a; k_par b; k_one c1; k_cmp d; int bad;
    bad = 0;
    a = new; b = new; c1 = new; d = new;
    if (!a.randomize()) begin $display("FAIL wide literal"); bad++; end
    else if (a.f[0] !== 66'h2_0000_0005_0000_0063 || a.f[1] === a.f[0]) begin $display("FAIL wide literal value %h", a.f[0]); bad++; end
    if (!b.randomize()) begin $display("FAIL param table"); bad++; end
    else if (b.f[0] !== DEF[0] || b.f[1] !== DEF[1] || b.f[2] !== DEF[2]) begin $display("FAIL param table values"); bad++; end
    if (!c1.randomize()) begin $display("FAIL scalar param[const]"); bad++; end
    else if (c1.v !== DEF[1]) begin $display("FAIL scalar value"); bad++; end
    if (!d.randomize() || d.v !== d.u) begin $display("FAIL wide eq"); bad++; end
    if (bad == 0) $display("PASSED");
  end
endmodule
