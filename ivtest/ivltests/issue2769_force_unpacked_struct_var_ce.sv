// IEEE 1800-2023 10.6.2: the left-hand side of a force "can be a reference
// to a singular variable, a net, ..."; 6.4: an unpacked structure is not
// singular. A whole unpacked struct variable, or an element of an array of
// them, is therefore not a force target (ruling on #2769).
module t;
  typedef struct { int a; logic [3:0] b; } S2;
  S2 v, f, arr [0:1];
  initial begin
    force v = f;
    force arr[1] = f;
  end
endmodule
