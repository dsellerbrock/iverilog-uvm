class C;
  rand bit m;
  rand bit [15:0] arr[2];
  constraint c1 { solve m before arr; foreach (arr[i]) m -> arr[i] == 5; }
endclass
class N;
  rand bit m;
  rand bit [15:0] arr[2];
  constraint c1 { foreach (arr[i]) m -> arr[i] == 5; }
endclass
module top; C c; N n; int oc, on; initial begin c = new; n = new;
  repeat (400) begin void'(c.randomize()); oc += c.m; void'(n.randomize()); on += n.m; end
  $display("ordered m=1: %0d/400  unordered m=1: %0d/400", oc, on); end endmodule
