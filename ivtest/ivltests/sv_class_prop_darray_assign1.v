module test;

  class holder;
    bit [7:0] data[];

    function void init();
      data = new[2];
      data[0] = 8'h12;
      data[1] = 8'h34;
    endfunction
  endclass

  bit [7:0] tmp[];

  initial begin
    holder h;

    h = new;
    h.init();

    tmp = h.data;
    if (tmp.size() != 2) begin
      $display("FAILED size=%0d", tmp.size());
      $finish(1);
    end
    if (tmp[0] !== 8'h12 || tmp[1] !== 8'h34) begin
      $display("FAILED init values %h %h", tmp[0], tmp[1]);
      $finish(1);
    end

    h.data[1] = 8'h56;
    tmp = h.data;
    if (tmp[1] !== 8'h56) begin
      $display("FAILED updated value %h", tmp[1]);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
