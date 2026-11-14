interface class A; parameter int X = 1; endclass
interface class B; parameter int X = 1; endclass
interface class C extends A, B; endclass
interface class D; parameter int Y = 3; endclass
interface class E extends D; endclass
interface class F; parameter int Y = 4; endclass
interface class G extends E, F; endclass
interface class H; typedef int Z; endclass
interface class I; parameter int Z = 5; endclass
interface class J extends H, I; endclass
module test; endmodule
