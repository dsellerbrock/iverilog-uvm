module issue3194_readmem_enum;
  typedef enum logic [2:0] { A=0, B=1, C=2, D=5 } e_t;
  typedef enum bit [2:0] { X=0, Y=1, Z=2 } b_t;
  e_t q[$], d[], a[int], f[3];
  b_t b[$];
  initial begin
    q = '{A, A, A};
    $readmemh("ivltests/issue3194_readmem_enum.hex", q);
    if (q.size() != 3 || q[0] !== B || q[1] !== A || q[2] !== A)
      $fatal(1, "queue changed after invalid word");
    d = new[3];
    d[0] = A; d[1] = A; d[2] = A;
    $readmemh("ivltests/issue3194_readmem_enum.hex", d);
    if (d[0] !== B || d[1] !== A || d[2] !== A)
      $fatal(1, "dynamic array changed after invalid word");
    $readmemh("ivltests/issue3194_readmem_enum.hex", a);
    if (a.num() != 1 || a[0] !== B || a.exists(1) || a.exists(2))
      $fatal(1, "associative array inserted invalid word");
    a[1] = A; a[2] = A;
    $readmemh("ivltests/issue3194_readmem_enum.hex", a);
    if (a.num() != 3 || a[0] !== B || a[1] !== A || a[2] !== A)
      $fatal(1, "associative array changed after invalid word");
    f[0] = A; f[1] = A; f[2] = A;
    $readmemh("ivltests/issue3194_readmem_enum.hex", f);
    if (f[0] !== B || f[1] !== A || f[2] !== A)
      $fatal(1, "fixed array changed after invalid word");
    b = '{X, X, X};
    $readmemb("ivltests/issue3194_readmem_enum.bin", b);
    if (b[0] !== Y || b[1] !== X || b[2] !== X)
      $fatal(1, "2-state queue changed after invalid word");
    $readmemh("ivltests/issue3194_readmem_enum_valid.hex", q);
    $readmemh("ivltests/issue3194_readmem_enum_valid.hex", d);
    $readmemh("ivltests/issue3194_readmem_enum_valid.hex", a);
    if (q[0] !== B || q[1] !== D || q[2] !== C ||
        d[0] !== B || d[1] !== D || d[2] !== C ||
        a.num() != 3 || a[0] !== B || a[1] !== D || a[2] !== C)
      $fatal(1, "valid enum words were not all loaded");
    $display("PASS");
    $finish;
  end
endmodule
