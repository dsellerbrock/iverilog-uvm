interface i;
  logic a;
  modport m(input a);
endinterface
module mm(i.m p);
  initial p.a = 1;
endmodule
module t;
  i ii();
  mm u(ii);
endmodule
