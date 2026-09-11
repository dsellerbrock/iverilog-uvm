class holder; typedef enum {A,B} state; endclass
module test; holder::state x; typedef enum {C,D} other; other y; initial x=y; endmodule
