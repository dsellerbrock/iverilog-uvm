module t;
 typedef mailbox #(string) sm_t;
 sm_t m = new;
 initial m.put(5);
endmodule
