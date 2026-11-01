typedef enum {ON, OFF} switch_e;
typedef struct {switch_e sw; string s;} pair_t;

module test;
  switch_e e = OFF;
  pair_t p = '{OFF, "hi"};

  initial begin
    $display("e=%p", e);
    $display("p=%p", p);
    $display("ISSUE802_PASSED");
    $display("PASSED");
    $finish;
  end
endmodule
