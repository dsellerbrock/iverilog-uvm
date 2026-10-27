module t;
  typedef enum {red, green, blue, yellow} Colors;
  typedef enum logic [3:0] {Z0='z, X1='x} E4;
  typedef enum bit [3:0] {ONES='1, ZERO='0} E2;
  typedef struct { Colors col; } st_t;
  st_t st;
  Colors c;
  initial begin
    c = green;
    st.col = blue;
    $display("K1 plain: first=%0d next=%0d last=%0d name=%s", c.first, c.next, c.last, c.name);
    $display("K2 struct bare: first=%0d next=%0d name=%s", st.col.first, st.col.next, st.col.name);
    $display("K3 struct explicit: first=%0d next=%0d name=%s", st.col.first(), st.col.next(), st.col.name());
    $display("K5 values: ONES=%b ZERO=%b Z0=%b X1=%b", ONES, ZERO, Z0, X1);
  end
endmodule
