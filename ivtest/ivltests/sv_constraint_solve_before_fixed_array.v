// A whole fixed rand array in solve...before orders each of its integral
// elements (IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9 Table 18-2 analogue):
// with 'solve m before arr', m is about 1/2 even though m == 1 pins arr.
typedef struct { rand bit [15:0] clkdiv[2]; } cfg_t;
class C; rand bit m; rand bit [15:0] arr[2];
  constraint c { solve m before arr; foreach (arr[i]) m -> arr[i] == 5; } endclass
class D; rand bit m; rand cfg_t s;
  constraint c { solve m before s.clkdiv; foreach (s.clkdiv[i]) m -> s.clkdiv[i] == 5; } endclass
class B; rand bit m; rand bit [15:0] arr[3:1];
  constraint c { solve m before arr; foreach (arr[i]) m -> arr[i] == 5; } endclass

module top;
  C c; D d; B b;
  int fails, oc, od, ob;
  initial begin
    c = new; d = new; b = new;
    repeat (400) begin
      if (!c.randomize()) fails++;
      if (!d.randomize()) fails++;
      if (!b.randomize()) fails++;
      oc += c.m; od += d.m; ob += b.m;
      if (c.m && (c.arr[0] != 5 || c.arr[1] != 5)) fails++;
      if (d.m && (d.s.clkdiv[0] != 5 || d.s.clkdiv[1] != 5)) fails++;
      if (b.m && (b.arr[1] != 5 || b.arr[3] != 5)) fails++;
    end
    if (fails == 0 && oc inside {[150:250]} && od inside {[150:250]}
        && ob inside {[150:250]})
      $display("PASSED");
    else
      $display("FAILED fails=%0d c=%0d d=%0d b=%0d", fails, oc, od, ob);
  end
endmodule
