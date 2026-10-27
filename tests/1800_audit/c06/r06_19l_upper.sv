module t; typedef enum {red, green, blue} Colors; Colors c;
 initial begin c = green; $display("upper => %s", c.name.toupper()); end endmodule
