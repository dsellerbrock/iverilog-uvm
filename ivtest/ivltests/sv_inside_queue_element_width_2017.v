module sv_inside_queue_element_width_2017;
  bit [3:0] x = 1;
  int q[$] = '{17};

  initial begin
    if (x inside {q}) begin
      $display("FAILED -- wider queue element was truncated");
      $finish(1);
    end
    q[0] = 1;
    if (!(x inside {q})) begin
      $display("FAILED -- matching queue element was missed");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
