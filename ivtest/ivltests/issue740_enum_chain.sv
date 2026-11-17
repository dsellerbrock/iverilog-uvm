// IEEE 1800 6.19.5 (owner ruling 2026-11-10): paren-less enum methods chain.
module top;
  typedef enum {red, green, blue} Colors;
  Colors c;
  initial begin
    c = red;
    $display("%0d %s %s %s", c.name.len, c.next.name, c.prev.name, c.next.next.name);
    c = green;
    $display("%0d %s %s %s", c.name.len, c.next.name, c.prev.name, c.prev.prev.name);
    c = blue;
    $display("%0d %s %s %0d", c.name.len, c.next.name, c.prev.name, c.next.name.len);
    $display("%0d %s %s", c.name.len(), c.name.toupper(), c.next().name());
    $display("%s %s", c.first.name, c.last.name);
  end
endmodule
