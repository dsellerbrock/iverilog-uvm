package p1; typedef struct {int A;} t_1; endpackage module sub(); typedef struct {int A;} t_5; t_5 v5; endmodule module m; sub s1(); sub s2(); initial s1.v5 = s2.v5; endmodule
