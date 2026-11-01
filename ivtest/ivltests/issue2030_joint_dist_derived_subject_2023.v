module main;
  class leaf;
    rand bit seen;
  endclass

  class selected_array_dist;
    rand leaf child;
    rand bit [2:0] read_enable;
    rand bit [1:0] index;
    function new(); child = new; endfunction
    constraint c {
      index inside {[0:2]};
      read_enable[index] dist {1'b1 :/ 3, 1'b0 :/ 1};
      child.seen == read_enable[0];
    }
  endclass

  class packed_member_dist;
    typedef struct packed { bit s; bit [2:0] data; } packed_t;
    rand leaf child;
    rand packed_t p;
    constraint c {
      p.s dist {1'b1 :/ 3, 1'b0 :/ 1};
      child.seen == p.data[0];
    }
    function new(); child = new; endfunction
  endclass

  initial begin
    selected_array_dist a;
    packed_member_dist c;
    int ok_a, ones_a, ok_c, ones_c;
    a = new;
    c = new;
    ok_a = 0; ones_a = 0; ok_c = 0; ones_c = 0;
    repeat (100) begin
      ok_a += a.randomize();
      ones_a += a.read_enable[a.index];
      ok_c += c.randomize();
      ones_c += c.p.s;
    end
    if (ok_a != 100 || ones_a < 60 || ones_a > 90
        || ok_c != 100 || ones_c < 60 || ones_c > 90)
      $fatal(1, "joint derived dist results: %0d/%0d %0d/%0d",
          ok_a, ones_a, ok_c, ones_c);
    $display("joint derived dist passed");
  end
endmodule
