module test;
  class base_holder;
    int inherited_padding;
  endclass

  class holder #(type T = int) extends base_holder;
    const static string type_name = "holder #(T)";
    const static int marker = 17;

    static function string get_type_name();
      return type_name;
    endfunction
  endclass

  initial begin
    if (holder#(byte)::get_type_name() != "holder #(T)") begin
      $display("FAILED type_name");
      $finish(1);
    end
    if (holder#(byte)::marker != 17) begin
      $display("FAILED marker=%0d", holder#(byte)::marker);
      $finish(1);
    end
    if (holder#(int)::get_type_name() != "holder #(T)" ||
        holder#(int)::marker != 17) begin
      $display("FAILED default specialization");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
