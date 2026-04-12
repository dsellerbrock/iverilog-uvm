typedef class cb_t;

class base_cb;
  function bit callback_mode();
    return 1;
  endfunction
endclass

class callbacks #(type CB = base_cb);
  static function CB get_first();
    CB cb = null;
    if (cb == null)
      return cb;
    if (cb.callback_mode())
      return cb;
    return null;
  endfunction
endclass

class iter #(type CB = base_cb);
  local CB m_cb;
  function CB first();
    m_cb = callbacks#(CB)::get_first();
    return m_cb;
  endfunction
endclass

class cb_t extends base_cb;
endclass

typedef iter#(cb_t) iter_cb_t;

module test;
  iter_cb_t i;
  cb_t cb;
  initial begin
    i = new;
    cb = i.first();
    if (cb == null)
      $display("PASS");
    else begin
      $display("FAIL: expected null");
      $finish(1);
    end
  end
endmodule
