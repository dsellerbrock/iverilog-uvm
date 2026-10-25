module t; typedef enum {red, green, blue} Colors; Colors c;
 initial begin c = green; $display("lenbare => %0d", c.name.len); end endmodule
