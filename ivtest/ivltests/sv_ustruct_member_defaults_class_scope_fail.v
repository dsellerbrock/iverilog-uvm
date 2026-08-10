module sv_ustruct_member_defaults_class_scope_fail;
  typedef class owner;

  class owner;
    localparam integer BASE = 50;
    typedef struct {
      integer value = BASE + 1;
    } record_t;
  endclass

  initial begin
    owner::record_t outside_value;
  end
endmodule
