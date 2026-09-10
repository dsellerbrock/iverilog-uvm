class types;
  localparam int number=7;
  static int value;
endclass
class accept #(type T=int);
  static function int width(); return $bits(T); endfunction
endclass
module main;
  int value;
  initial begin
    $display("%0d",accept#(types::number)::width());
    $display("%0d",accept#(types::value)::width());
    $display("%0d",accept#(main.value)::width());
  end
endmodule
