// IEEE 1800-2017/2023 8.19 and 12.7.1: a procedural for initializer
// shall not bypass ordinary assignment legality for a static class constant.
module top;
  class holder;
    const static int marker = 17;
    static function void overwrite;
      for (marker = 23; ; )
        break;
    endfunction
  endclass
endmodule
