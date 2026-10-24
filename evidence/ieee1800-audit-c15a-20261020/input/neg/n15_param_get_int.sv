module t;
 typedef mailbox #(string) sm_t;
 sm_t m = new;
 int x;
 initial m.get(x);
endmodule
