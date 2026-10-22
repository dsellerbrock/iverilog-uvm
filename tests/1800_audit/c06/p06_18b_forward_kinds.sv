typedef enum fe_t;
typedef struct fs_t;
typedef union fu_t;
typedef class fc_t;
typedef fl_t;
typedef enum fe2_t; typedef enum fe2_t;
typedef enum {FE_A, FE_B} fe_t;
typedef struct {int a;} fs_t;
typedef union {int i; bit [31:0] b;} fu_t;
class fc_t; int z=3; endclass
typedef int fl_t;
typedef enum {X2} fe2_t;
module p06_18b;
  fe_t fe; fs_t fs; fu_t fu; fc_t fc; fl_t fl; fe2_t e2;
  initial begin fe=FE_B; fs.a=3; fu.i=5; fc=new; fl=9; e2=X2;
    $display("FWD enum=%0d struct=%0d union=%0d class=%0d generic=%0d duplicate=%0d",fe,fs.a,fu.i,fc.z,fl,e2);
  end
endmodule
