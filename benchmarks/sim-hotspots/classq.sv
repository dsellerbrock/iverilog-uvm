// Class/queue/mailbox-heavy testbench style.
class txn;
  rand bit [31:0] addr; rand bit [31:0] data; int id;
  function new(int i); id = i; addr = i*4; data = i ^ 32'hdeadbeef; endfunction
  virtual function bit [31:0] crc(); return addr ^ data ^ id; endfunction
endclass
class btxn extends txn;
  function new(int i); super.new(i); endfunction
  virtual function bit [31:0] crc(); return super.crc() + 1; endfunction
endclass
module top;
  mailbox #(txn) mb = new(16);
  txn q[$];
  bit [31:0] chk = 0;
  int n = 0;
  initial begin
    for (int i=0;i<200000;i++) begin
      automatic btxn b = new(i);
      automatic txn t = b;
      mb.put(t);
    end
  end
  initial begin : consumer
    static txn t;
    forever begin
      mb.get(t);
      q.push_back(t);
      if (q.size() > 8) begin automatic txn o = q.pop_front(); chk ^= o.crc(); end
      n++;
      if (n == 200000) begin $display("chk=%h n=%0d", chk, n); $finish; end
    end
  end
endmodule
