module sv_member_delay_strict_fail;
 typedef struct {time offset;} setting_t;
 setting_t setting;
 initial #setting.offset;
endmodule
