class reg_t #(type T = int);
  typedef reg_t#(T) this_type;

  static function this_type get();
    static this_type m_inst;

    if (m_inst == null)
      m_inst = new;

    return m_inst;
  endfunction
endclass

module test;
  initial begin
    reg_t#(int) a, b;
    reg_t#(byte) c;

    a = reg_t#(int)::get();
    b = reg_t#(int)::get();
    c = reg_t#(byte)::get();

    if (a == null || b == null || c == null) begin
      $display("FAILED: singleton returned null");
      $finish(1);
    end

    if (a !== b) begin
      $display("FAILED: same specialization did not share static local");
      $finish(1);
    end

    if (a === c) begin
      $display("FAILED: specializations shared one static local");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
