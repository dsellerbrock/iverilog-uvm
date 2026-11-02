package pkg;
  int used = 17;
  int unused = 18;
endpackage

module top;
  import pkg::used;
  import pkg::unused;
  int copy;

  initial begin
    copy = used;
    #0;
    $probe_imports;
    $finish;
  end
endmodule
