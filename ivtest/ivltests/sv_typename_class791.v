package A;
  typedef struct {bit z;} package_t;
  class Cl;
    typedef struct {bit c;} ct;
    typedef ct alias_t;
    typedef enum {ZERO, ONE} et;
    typedef union packed {bit [7:0] b; byte v;} ut;
    ct v;
    alias_t alias_v[2];
    et e;
    enum {LOW, HIGH} anon;
    ut u;
    package_t p;
    function string struct_name(); return $typename(v); endfunction
    function string alias_name(); return $typename(alias_v); endfunction
    function string enum_name(); return $typename(e); endfunction
    function string anon_name(); return $typename(anon); endfunction
    function string union_name(); return $typename(u); endfunction
    function string package_name(); return $typename(p); endfunction
  endclass
endpackage

module top;
  class Local;
    typedef struct {int x;} st;
    st v;
    function string name(); return $typename(v); endfunction
  endclass
  A::Cl ch;
  Local local_ch;
  initial begin
    ch = new;
    local_ch = new;
    if (ch.struct_name() != "struct{bit c;}A::Cl::ct" ||
        ch.alias_name() != "struct{bit c;}A::Cl::ct$[0:1]" ||
        ch.enum_name() != "enum{ZERO=32'sd0,ONE=32'sd1}A::Cl::et" ||
        ch.anon_name() != "enum{LOW=32'sd0,HIGH=32'sd1}A::Cl::e$2" ||
        ch.union_name() != "union packed{bit [7:0] b;byte v;}A::Cl::ut" ||
        ch.package_name() != "struct{bit z;}A::package_t" ||
        local_ch.name() != "struct{int x;}top.Local::st") begin
      $display("FAILED: [%s] [%s] [%s] [%s] [%s] [%s] [%s]", ch.struct_name(),
               ch.alias_name(), ch.enum_name(), ch.anon_name(), ch.union_name(),
               ch.package_name(), local_ch.name());
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
