typedef class Node;
class List; Node head; function void set(Node n); head=n; endfunction endclass
class Node; int v=7; endclass
module p06_18c; List l; Node n; initial begin l=new; n=new; l.set(n); $display("NODE=%0d",l.head.v); end endmodule
