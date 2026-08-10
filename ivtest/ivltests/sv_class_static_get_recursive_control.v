package class_static_get_recursive_pkg;
  class left_type;
  endclass

  class right_type;
  endclass

  class pair_singleton #(type L = left_type, type R = right_type);
    typedef pair_singleton#(L, R) this_type;

    local static this_type m_inst;
    static pair_singleton#(R, L) m_peer;
    local static int m_marker;

    static function this_type get();
      if (m_inst == null) begin
        m_inst = new;

        // Both orientations refer to one another. Installing m_inst first
        // bounds the live recursion when the opposite orientation calls back.
        if (m_peer == null)
          m_peer = pair_singleton#(R, L)::get();
      end
      return m_inst;
    endfunction

    static function bit peer_linked();
      return m_peer != null;
    endfunction

    static function void set_marker(int value);
      m_marker = value;
    endfunction

    static function int marker();
      return m_marker;
    endfunction
  endclass
endpackage

module sv_class_static_get_recursive_control;
  import class_static_get_recursive_pkg::*;

  pair_singleton#(left_type, right_type) left_right_0;
  pair_singleton#(left_type, right_type) left_right_1;
  pair_singleton#(right_type, left_type) right_left;

  initial begin
    left_right_0 = pair_singleton#(left_type, right_type)::get();
    left_right_1 = pair_singleton#(left_type, right_type)::get();
    right_left = pair_singleton#(right_type, left_type)::get();

    pair_singleton#(left_type, right_type)::set_marker(11);
    pair_singleton#(right_type, left_type)::set_marker(22);

    if (left_right_0 == null || left_right_0 != left_right_1 ||
        right_left == null ||
        !pair_singleton#(left_type, right_type)::peer_linked() ||
        !pair_singleton#(right_type, left_type)::peer_linked() ||
        pair_singleton#(left_type, right_type)::marker() != 11 ||
        pair_singleton#(right_type, left_type)::marker() != 22) begin
      $display("FAILED");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
