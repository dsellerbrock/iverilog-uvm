module t; typedef enum {red, green, blue} Colors; Colors c;
 initial begin c = green; $display("eqlit => %b", c.name == "green"); end endmodule
