class K;
  local function new();
  endfunction

  static function K make();
    K p;
    p = new;
    return p;
  endfunction
endclass

module top;
  K k;
  initial begin
    k = K::make();
    k = new;
  end
endmodule
