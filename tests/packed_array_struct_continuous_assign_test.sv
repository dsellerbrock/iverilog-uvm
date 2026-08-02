module packed_array_struct_continuous_assign_test;
  typedef struct packed {
    logic [9:0] min_v;
    logic [9:0] max_v;
    logic cond;
    logic en;
  } filter_ctl_t;

  typedef struct packed {
    logic [10:0] reserved;
    logic schmitt_en;
    logic [1:0] mode;
  } pad_attr_t;

  wire filter_ctl_t [1:0][1:0] controls;
  wire pad_attr_t [1:0] attrs;
  logic use_override = 1'b1;

  assign controls[0][0] = '{
    min_v: 10'h012,
    max_v: 10'h345,
    cond:  1'b1,
    en:    1'b0
  };
  assign attrs[0] = use_override
      ? '{schmitt_en: 1'b1, default: '0}
      : attrs[1];
  assign attrs[1] = '0;

  initial begin
    #1;
    if (controls[0][0].min_v !== 10'h012 ||
        controls[0][0].max_v !== 10'h345 ||
        controls[0][0].cond !== 1'b1 || controls[0][0].en !== 1'b0 ||
        attrs[0].schmitt_en !== 1'b1 || attrs[0].reserved !== '0 ||
        attrs[0].mode !== '0)
      $fatal(1, "packed-array struct continuous assignment failed");
    use_override = 1'b0;
    #1;
    if (attrs[0] !== attrs[1] || attrs[0] !== '0)
      $fatal(1, "packed-array struct element read failed");
    $display("PASS: packed-array struct continuous assignment");
  end
endmodule
