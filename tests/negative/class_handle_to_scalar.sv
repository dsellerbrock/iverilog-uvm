// M1B-3 audit finding A: a class handle assigned to a non-class target
// at module scope was silently substituted with 0. 8.4 lists the only
// operators valid on handles; this must be a hard error.
class C; int v; endclass
module t;
  C c;
  int i;
  initial begin c = new; i = c; end
endmodule
