module t; typedef enum {red, green, blue} Colors; Colors c;
 initial begin c = green; $display("nextname2 => %s", c.next().name()); end endmodule
