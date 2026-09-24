/* Local replacement for Caliptra's unavailable random_test_ml_kem.py.
 * Implements only the pinned testbench's keygen (1) and encap (2) file protocol.
 * OpenSSL 3.5+ provides the FIPS 203 deterministic inputs used here.
 */
#include <openssl/core_names.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/params.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { SEED_SIZE = 32, EK_SIZE = 1568, DK_SIZE = 3168, CT_SIZE = 1568 };

static void fail(const char *message)
{
    fprintf(stderr, "native_mlkem: %s\n", message);
    ERR_print_errors_fp(stderr);
    exit(1);
}

static int hex_digit(char digit)
{
    if (digit >= '0' && digit <= '9') return digit - '0';
    if (digit >= 'a' && digit <= 'f') return digit - 'a' + 10;
    if (digit >= 'A' && digit <= 'F') return digit - 'A' + 10;
    return -1;
}

static void read_hex(FILE *file, unsigned char *out, size_t size)
{
    char line[2 * DK_SIZE + 3];
    if (!fgets(line, sizeof line, file)) fail("missing input line");
    size_t n = strcspn(line, "\r\n");
    if (n != size * 2 || line[n] == 0) fail("wrong input line length");
    for (size_t i = 0; i < size; ++i) {
        int hi = hex_digit(line[2 * i]);
        int lo = hex_digit(line[2 * i + 1]);
        if (hi < 0 || lo < 0) fail("invalid hex");
        out[i] = (unsigned char)((hi << 4) | lo);
    }
}

static void write_hex(FILE *file, const unsigned char *data, size_t size)
{
    for (size_t i = 0; i < size; ++i)
        if (fprintf(file, "%02X", data[i]) < 0) fail("write failed");
    if (fputc('\n', file) == EOF) fail("write failed");
}

static void keygen(FILE *input, FILE *output)
{
    unsigned char z[SEED_SIZE], d[SEED_SIZE], seed[2 * SEED_SIZE];
    unsigned char ek[EK_SIZE], dk[DK_SIZE];
    size_t ek_size = sizeof ek, dk_size = sizeof dk;
    read_hex(input, z, sizeof z);
    read_hex(input, d, sizeof d);
    memcpy(seed, d, sizeof d);
    memcpy(seed + sizeof d, z, sizeof z);

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_from_name(NULL, "ML-KEM-1024", NULL);
    if (!ctx || EVP_PKEY_keygen_init(ctx) <= 0) fail("keygen init failed");
    OSSL_PARAM params[] = {
        OSSL_PARAM_octet_string(OSSL_PKEY_PARAM_ML_KEM_SEED, seed, sizeof seed),
        OSSL_PARAM_END
    };
    if (EVP_PKEY_CTX_set_params(ctx, params) <= 0) fail("seed rejected");
    EVP_PKEY *key = NULL;
    if (EVP_PKEY_keygen(ctx, &key) <= 0) fail("keygen failed");
    if (EVP_PKEY_get_raw_public_key(key, ek, &ek_size) <= 0 || ek_size != EK_SIZE)
        fail("unexpected encapsulation key");
    if (EVP_PKEY_get_raw_private_key(key, dk, &dk_size) <= 0 || dk_size != DK_SIZE)
        fail("unexpected decapsulation key");

    fputs("1\n", output);
    write_hex(output, z, sizeof z);
    write_hex(output, d, sizeof d);
    write_hex(output, ek, sizeof ek);
    write_hex(output, dk, sizeof dk);
    EVP_PKEY_free(key);
    EVP_PKEY_CTX_free(ctx);
}

static void encap(FILE *input, FILE *output)
{
    unsigned char message[SEED_SIZE], ek[EK_SIZE], secret[SEED_SIZE], ct[CT_SIZE];
    size_t secret_size = sizeof secret, ct_size = sizeof ct;
    read_hex(input, message, sizeof message);
    read_hex(input, ek, sizeof ek);

    EVP_PKEY_CTX *import = EVP_PKEY_CTX_new_from_name(NULL, "ML-KEM-1024", NULL);
    if (!import || EVP_PKEY_fromdata_init(import) <= 0) fail("key import init failed");
    OSSL_PARAM key_params[] = {
        OSSL_PARAM_octet_string(OSSL_PKEY_PARAM_PUB_KEY, ek, sizeof ek),
        OSSL_PARAM_END
    };
    EVP_PKEY *key = NULL;
    if (EVP_PKEY_fromdata(import, &key, EVP_PKEY_PUBLIC_KEY, key_params) <= 0)
        fail("encapsulation key rejected");
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL);
    if (!ctx) fail("encapsulation init failed");
    OSSL_PARAM params[] = {
        OSSL_PARAM_octet_string(OSSL_KEM_PARAM_IKME, message, sizeof message),
        OSSL_PARAM_END
    };
    if (EVP_PKEY_encapsulate_init(ctx, params) <= 0) fail("message rejected");
    if (EVP_PKEY_encapsulate(ctx, ct, &ct_size, secret, &secret_size) <= 0 ||
        ct_size != CT_SIZE || secret_size != SEED_SIZE)
        fail("encapsulation failed");

    fputs("2\n", output);
    write_hex(output, message, sizeof message);
    write_hex(output, ek, sizeof ek);
    write_hex(output, secret, sizeof secret);
    write_hex(output, ct, sizeof ct);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    EVP_PKEY_CTX_free(import);
}

int main(int argc, char **argv)
{
    if (argc != 6 || (strcmp(argv[1], "1") && strcmp(argv[1], "2")) ||
        strcmp(argv[2], "-i") || strcmp(argv[4], "-o"))
        fail("expected: native_mlkem {1|2} -i INPUT -o OUTPUT");
    FILE *input = fopen(argv[3], "r");
    if (!input) fail("cannot open input");
    char opcode[16];
    if (!fgets(opcode, sizeof opcode, input) ||
        opcode[0] != argv[1][0] || (opcode[1] != '\n' && opcode[1] != '\r'))
        fail("operation code mismatch");

    /* Truncate stale output; a failed helper returns nonzero to the testbench. */
    FILE *output = fopen(argv[5], "w");
    if (!output) fail("cannot open output");
    if (argv[1][0] == '1') keygen(input, output);
    else encap(input, output);
    if (fclose(output) != 0) fail("output close failed");
    if (fclose(input) != 0) fail("input close failed");
    return 0;
}
