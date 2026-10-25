module t;
 mailbox mb = new;
 int x;
 initial begin
  mb.put("text");
  mb.get(x);
  $display("SURVIVED %0d", x);
 end
endmodule
