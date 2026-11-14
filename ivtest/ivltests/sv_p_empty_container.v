// IEEE 1800-2023 21.2.1.6: %p prints an empty dynamic array or queue as '{};
// null is printed only for a null class handle.
class sv_p_empty_container_c;
endclass

class sv_p_empty_container_h;
  byte d[3][];
endclass

module sv_p_empty_container;
  int md[2][];
  int mq[2][$];
  int dd[][];
  sv_p_empty_container_c mc[2];
  initial begin
    automatic sv_p_empty_container_h h = new;
    h.d[0] = new[2];
    md[1] = new[1];
    dd = new[2];
    $display("%p", h.d);
    $display("%p", md);
    $display("%p", mq);
    $display("%p", dd);
    $display("%p", mc);
  end
endmodule
