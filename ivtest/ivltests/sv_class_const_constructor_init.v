module test;
  class holder;
    const int marker;

    function new(input int value);
      marker = value;
    endfunction
  endclass

  initial begin
    holder object;
    object = new(29);
    if (object.marker != 29) begin
      $display("FAILED marker=%0d", object.marker);
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
