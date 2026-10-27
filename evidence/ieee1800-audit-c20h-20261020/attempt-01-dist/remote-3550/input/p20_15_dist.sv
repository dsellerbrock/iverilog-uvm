module p20_15_dist;
  integer s_random, s_uniform, s_normal, s_exponential;
  integer s_poisson, s_chi_square, s_t, s_erlang;
  integer i;

  initial begin
    s_random = 1;
    $write("$random");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $random(s_random));
    $display(" seed %0d", s_random);

    s_uniform = 1;
    $write("$dist_uniform");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_uniform(s_uniform, 0, 100));
    $display(" seed %0d", s_uniform);

    s_normal = 1;
    $write("$dist_normal");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_normal(s_normal, 0, 10));
    $display(" seed %0d", s_normal);

    s_exponential = 1;
    $write("$dist_exponential");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_exponential(s_exponential, 10));
    $display(" seed %0d", s_exponential);

    s_poisson = 1;
    $write("$dist_poisson");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_poisson(s_poisson, 5));
    $display(" seed %0d", s_poisson);

    s_chi_square = 1;
    $write("$dist_chi_square");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_chi_square(s_chi_square, 3));
    $display(" seed %0d", s_chi_square);

    s_t = 1;
    $write("$dist_t");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_t(s_t, 4));
    $display(" seed %0d", s_t);

    s_erlang = 1;
    $write("$dist_erlang");
    for (i = 0; i < 5; i = i + 1) $write(" %0d", $dist_erlang(s_erlang, 2, 10));
    $display(" seed %0d", s_erlang);
  end
endmodule
