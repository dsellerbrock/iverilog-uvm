class issue2979_leaf;
  int v;
endclass

class issue2979_and_left;
  bit gate = 0; issue2979_leaf h; rand bit x;
  constraint c { ((h.v == 1) && gate) -> (x == 1); x == 0; }
endclass
class issue2979_and_right;
  bit gate = 0; issue2979_leaf h; rand bit x;
  constraint c { (gate && (h.v == 1)) -> (x == 1); x == 0; }
endclass
class issue2979_or_left;
  bit gate = 1; issue2979_leaf h; rand bit x;
  constraint c { ((h.v == 1) || gate) -> (x == 1); }
endclass
class issue2979_or_right;
  bit gate = 1; issue2979_leaf h; rand bit x;
  constraint c { (gate || (h.v == 1)) -> (x == 1); }
endclass
class issue2979_nested;
  bit gate = 1; issue2979_leaf h; rand bit x;
  constraint c { if ((!((h.v == 1) || gate)) && (h.v == 2))
                   x == 1;
                 else x == 0; }
endclass
class issue2979_nested_random;
  bit gate = 1; issue2979_leaf h; rand bit x, y;
  constraint c { (((h.v == 1) || gate) && x) -> (y == 1); x == 1; }
endclass
class issue2979_nondeciding_and;
  bit gate = 1; issue2979_leaf h; rand bit x;
  constraint c { ((h.v == 1) && gate) -> (x == 1); }
endclass
class issue2979_nondeciding_or;
  bit gate = 0; issue2979_leaf h; rand bit x;
  constraint c { ((h.v == 1) || gate) -> (x == 1); }
endclass
class issue2979_non_guard;
  bit gate = 1; issue2979_leaf h; rand bit x;
  constraint c { ((h.v == 1) || gate); x == 1; }
endclass
class issue2979_random_and;
  issue2979_leaf h; rand bit x, y;
  constraint c { ((h.v == 1) && x) -> (y == 1); }
endclass
class issue2979_random_or;
  issue2979_leaf h; rand bit x, y;
  constraint c { (x || (h.v == 1)) -> (y == 1); }
endclass

module main;
  issue2979_and_left a; issue2979_and_right b;
  issue2979_or_left c; issue2979_or_right d;
  issue2979_nested e; issue2979_random_and f; issue2979_random_or g;
  issue2979_nondeciding_and h; issue2979_nondeciding_or i;
  issue2979_non_guard j; issue2979_nested_random k;
  int ra, rb, rc, rd, re, rf, rg, rh, ri, rj, rk;
  initial begin
    a=new; b=new; c=new; d=new; e=new; f=new; g=new; h=new; i=new; j=new; k=new;
    ra=a.randomize(); rb=b.randomize(); rc=c.randomize(); rd=d.randomize();
    re=e.randomize(); rf=f.randomize(); rg=g.randomize();
    rh=h.randomize(); ri=i.randomize(); rj=j.randomize(); rk=k.randomize();
    if (ra != 1 || rb != 1 || rc != 1 || rd != 1 || re != 1 ||
        rf != 0 || rg != 0 || rh != 0 || ri != 0 || rj != 0 || rk != 1 || k.x != 1 || k.y != 1 || c.x != 1 || d.x != 1 || e.x != 0)
      $display("FAILED: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d values %0d %0d %0d",
               ra, rb, rc, rd, re, rf, rg, rh, ri, rj, rk, c.x, d.x, e.x);
    else $display("PASSED");
  end
endmodule
