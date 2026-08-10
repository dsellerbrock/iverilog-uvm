class collision;
  static int class_only = 99;
endclass

class reader;
  function int read_bad;
    int collision;
    begin : nested
      // The nearer scalar value declaration wins. It has no class_only
      // member, so lookup must not recover the outer class.
      return collision.class_only;
    end
  endfunction
endclass

module test;
  initial begin
    reader r;
    r = new;
    $display("SHOULD_NOT_COMPILE %0d", r.read_bad());
  end
endmodule
