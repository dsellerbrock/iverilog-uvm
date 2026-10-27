program p;
  typedef int count_t;
  class sample_c;
    count_t n;
  endclass

  count_t n = 3;
  wire w;
  assign w = 1'b1;

  task check;
    if (w !== 1'b1 || n != 3)
      $fatal(1, "program item check failed");
  endtask

  initial begin
    check();
  end

  final $display("FIN");
endprogram
