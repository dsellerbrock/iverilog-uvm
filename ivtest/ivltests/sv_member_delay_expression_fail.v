module sv_member_delay_expression_fail;
 typedef struct {time offset;} setting_t;
 setting_t setting;
 initial #setting.offset+1;
 initial #setting.offset[0];
 initial #setting.offset();
endmodule
