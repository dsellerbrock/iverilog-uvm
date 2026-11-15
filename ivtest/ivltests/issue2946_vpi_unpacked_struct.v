module top;
  typedef struct { int a; logic [3:0] b; } st;
  typedef union { int a; logic [31:0] b; } un;
  class cls; int a; endclass
  st s;
  un u;
  cls c;
  initial begin
    $probe_issue2946;
    c = new;
    $probe_issue2946;
    $finish;
  end
endmodule
