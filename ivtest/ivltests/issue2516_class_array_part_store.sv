module issue2516_class_array_part_store;
  class holder;
    bit [3:0][31:0] data [2];
    function bit [7:0] upd(int i);
      data[i][0] = 32'h55667788;
      return 8'hBB;
    endfunction
    function void put(int i);
      data[i][1][7:0] = upd(i);
    endfunction
    function void put1(int i);
      data[i][1] = upd(i);
    endfunction
  endclass

  holder h;
  initial begin
    h = new;
    h.put(1);
    $display("nested %h", h.data[1]);
    h = new;
    h.put1(1);
    $display("one    %h", h.data[1]);
  end
endmodule
