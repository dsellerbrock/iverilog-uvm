module t; typedef enum {red, green, blue} Colors; Colors c;
 initial begin c = green; $display("nextname => %s", c.next.name); end endmodule
