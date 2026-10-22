module p18_05_3_default;
  class E4;
    rand bit [7:0] x;
    constraint c { x dist {[100:102] :/ 3, default :/ 1}; }
  endclass

  E4 e4;
  int in_r, out_r, distinct;
  bit seen[256];

  initial begin
    e4 = new;
    repeat (3000) begin
      void'(e4.randomize());
      if (e4.x inside {[100:102]}) in_r++;
      else begin
        out_r++;
        if (!seen[e4.x]) distinct++;
        seen[e4.x] = 1;
      end
    end
    $display("E4 in=%0d out=%0d distinct_out=%0d", in_r, out_r, distinct);
    $display("E4 t=%0t", $time);
  end
endmodule
