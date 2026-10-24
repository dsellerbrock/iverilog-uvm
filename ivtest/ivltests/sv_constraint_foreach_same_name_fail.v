class C;
  rand int A[];
  constraint c { foreach (A[A]) A[0] == 1; }
endclass

module test;
endmodule
