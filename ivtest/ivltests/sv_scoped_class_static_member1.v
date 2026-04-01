module test;
  class base_t;
    static string m_typename;
  endclass

  class holder_t;
    typedef holder_t this_user_type;
    typedef base_t super_type;

    static base_t m_t_inst;

    static function void init_names(string child_name, string base_name);
      if (m_t_inst == null)
        m_t_inst = new;

      super_type::m_typename = base_name;
      this_user_type::m_t_inst.m_typename = child_name;

      if (super_type::m_typename != child_name) begin
        $display("FAILED -- super_type::m_typename=%s expected %s",
                 super_type::m_typename, child_name);
        $finish(1);
      end

      if (this_user_type::m_t_inst.m_typename != child_name) begin
        $display("FAILED -- this_user_type::m_t_inst.m_typename=%s expected %s",
                 this_user_type::m_t_inst.m_typename, child_name);
        $finish(1);
      end
    endfunction
  endclass

  initial begin
    holder_t::init_names("child_alias", "base_alias");
    $display("PASSED");
  end
endmodule
