module test;
  class holder;
    const static int marker = 17;

    static function void overwrite();
      marker = 23;
    endfunction
  endclass

  initial begin
    holder::overwrite();
    $display("FAILED marker=%0d", holder::marker);
  end
endmodule
