#include "svdpi.h"

#include <limits.h>
#include <stdint.h>

char c_dpi_return_sbyte(void *ctx, const svLogicVecVal *d2p)
{
      if (ctx != 0 || d2p == 0 ||
          ((uint32_t)d2p[0].aval & 3u) != 3u ||
          ((uint32_t)d2p[0].bval & 3u) != 1u)
            return 0;
      return (char)0x80;
}

unsigned char c_dpi_return_ubyte(void *ctx, const svBitVecVal *d2p)
{
      if (ctx != 0 || d2p == 0 || ((uint32_t)d2p[0] & 0x7ffu) != 0x5a5u)
            return 0;
      return (unsigned char)0xfeu;
}

char c_dpi_plain_char_roundtrip(char value, char *out_value)
{
      unsigned char bits = (unsigned char)value;
      if (out_value == 0)
            return 0;
#if CHAR_MIN < 0
      if (value != (char)0x80)
            return 0;
#else
      if ((unsigned int)value != 0x80u)
            return 0;
#endif
      *out_value = (char)(bits ^ 0x55u);
      return (char)(bits + 3u);
}

short int c_dpi_return_sshort(int selector)
{
      return selector == 0x1234 ? (short int)0x8001 : 0;
}

unsigned short int c_dpi_return_ushort(int selector)
{
      return selector == 0x5678 ? (unsigned short int)0xfffeu : 0;
}

svBit c_dpi_return_bit(int selector)
{
      return selector == 7 ? sv_1 : sv_0;
}

svLogic c_dpi_return_logic(int selector)
{
      return selector == 0 ? sv_x : sv_z;
}

char c_dpi_return_byte_enum(void)
{
      return (char)-127;
}

unsigned int c_dpi_return_uint_enum(void)
{
      return 0xfeedbeefu;
}
