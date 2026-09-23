// solve...before restrictions (IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9)
// still apply to whole fixed arrays and to their selected elements.
typedef struct { bit [7:0] a[2]; } plain_t;
class Item; endclass
class N; rand bit m; bit [7:0] a[2]; constraint c { solve m before a; } endclass
class E; rand bit m; bit [7:0] a[2]; constraint c { solve m before a[0]; } endclass
class S; rand bit m; rand plain_t s; constraint c { solve m before s.a; } endclass
class K; rand bit m; randc bit [3:0] a[2]; constraint c { solve m before a; } endclass
class M; rand bit m; rand bit [7:0] a[2][2]; constraint c { solve m before a; } endclass
class H; rand bit m; rand Item a[2]; constraint c { solve m before a; } endclass
module top; N n = new; E e = new; S s = new; K k = new; M mm = new; H h = new; endmodule
