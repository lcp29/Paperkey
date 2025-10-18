/*
 * Copyright (C) 2007, 2008, 2009, 2012, 2016 David Shaw <dshaw@jabberwocky.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

/*
 * Copyright (C) 2025 helmholtz <helmholtz@fomal.host>
 */

#include "output.h"
#include "config.h"
#include "packets.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CRC24_POLY 0x864CFBL

void do_crc24(unsigned long *crc, const unsigned char *buf, size_t len) {
  size_t i;

  for (i = 0; i < len; i++) {
    int j;

    *crc ^= buf[i] << 16;
    for (j = 0; j < 8; j++) {
      *crc <<= 1;
      if (*crc & 0x1000000)
        *crc ^= CRC24_POLY;
    }
  }
}

static void print_base16(struct stream *output, const unsigned char *buf,
                         size_t length, unsigned int line_items,
                         unsigned long all_crc, unsigned int *line,
                         unsigned long *line_crc, unsigned int *offset) {
  // static unsigned long line_crc = CRC24_INIT;
  // static unsigned int line = 0;

  if (buf) {
    size_t i;

    for (i = 0; i < length; i++, (*offset)++) {
      if (*offset % line_items == 0) {
        if (*line) {
          stream_printf(output, "%06lX\n", *line_crc & 0xFFFFFFL);
          *line_crc = CRC24_INIT;
        }

        stream_printf(output, "%3u: ", ++*line);
      }

      stream_printf(output, "%02X ", buf[i]);

      do_crc24(line_crc, &buf[i], 1);
    }
  } else {
    stream_printf(output, "%06lX\n", *line_crc & 0xFFFFFFL);
    stream_printf(output, "%3u: %06lX\n", *line + 1, all_crc & 0xFFFFFFL);
  }
}

void print_bytes(struct stream *stream, const unsigned char *buf,
                 size_t length) {
  size_t i;

  for (i = 0; i < length; i++)
    stream_printf(stream, "%02X", buf[i]);
}

void output_file_format(struct stream *stream, const char *prefix) {
  stream_printf(stream, "%sFile format:\n", prefix);
  stream_printf(
      stream, "%sa) 1 octet:  Version of the paperkey format (currently 0).\n",
      prefix);
  stream_printf(stream,
                "%sb) 1 octet:  OpenPGP key or subkey version (currently 4)\n",
                prefix);
  stream_printf(
      stream,
      "%sc) n octets: Key fingerprint (20 octets for a version 4 key or "
      "subkey)\n",
      prefix);
  stream_printf(
      stream,
      "%sd) 2 octets: 16-bit big endian length of the following secret data\n",
      prefix);
  stream_printf(
      stream,
      "%se) n octets: Secret data: a partial OpenPGP secret key or subkey "
      "packet as\n",
      prefix);
  stream_printf(stream,
                "%s             specified in RFC 4880, starting with the "
                "string-to-key usage\n",
                prefix);
  stream_printf(
      stream,
      "%s             octet and continuing until the end of the packet.\n",
      prefix);
  stream_printf(stream,
                "%sRepeat fields b through e as needed to cover all subkeys.\n",
                prefix);
  stream_printf(stream, "%s\n", prefix);
  stream_printf(
      stream,
      "%sTo recover a secret key without using the paperkey program, use the\n",
      prefix);
  stream_printf(
      stream,
      "%skey fingerprint to match an existing public key packet with the\n",
      prefix);
  stream_printf(
      stream,
      "%scorresponding secret data from the paper key.  Next, append this "
      "secret\n",
      prefix);
  stream_printf(
      stream,
      "%sdata to the public key packet.  Finally, switch the public key "
      "packet tag\n",
      prefix);
  stream_printf(stream,
                "%sfrom 6 to 5 (14 to 7 for subkeys).  This will recreate the "
                "original secret\n",
                prefix);
  stream_printf(
      stream,
      "%skey or secret subkey packet.  Repeat as needed for all public key "
      "or subkey\n",
      prefix);
  stream_printf(stream,
                "%spackets in the public key.  All other packets (user IDs, "
                "signatures, etc.)\n",
                prefix);
  stream_printf(stream, "%smay simply be copied from the public key.\n",
                prefix);
}

int output_start(struct stream *output, enum data_type type,
                 unsigned char fingerprint[20], unsigned int output_width,
                 unsigned int *line_items) {
  // if (name) {
  //   if (type == RAW)
  //     output = fopen(name, "wb");
  //   else
  //     output = fopen(name, "w");

  //   if (!output)
  //     return -1;
  // } else {
  //   if (type == RAW)
  //     set_binary_mode(stdout);

  //   output = stdout;
  // }

  // output_type = type;

  switch (type) {
  case RAW:
    break;

  case AUTO:
  case BASE16: {
    time_t now = time(NULL);

    *line_items = (output_width - 5 - 6) / 3;
    stream_printf(output, "# Secret portions of key ");
    print_bytes(output, fingerprint, 20);
    stream_printf(output, "\n");
    stream_printf(output, "# Base16 data extracted %.24s\n", ctime(&now));
    stream_printf(output,
                  "# Created with " PACKAGE_STRING " by David Shaw\n#\n");
    output_file_format(output, "# ");
    stream_printf(output,
                  "#\n# Each base16 line ends with a CRC-24 of that line.\n");
    stream_printf(output,
                  "# The entire block of data ends with a CRC-24 of the "
                  "entire block of data.\n\n");
  } break;
  }

  return 0;
}

ssize_t output_bytes(struct stream *output, enum data_type type,
                     const unsigned char *buf, size_t length,
                     unsigned int line_items, unsigned long *all_crc,
                     unsigned int *line, unsigned long *line_crc,
                     unsigned int *offset) {
  ssize_t ret = -1;

  do_crc24(all_crc, buf, length);

  switch (type) {
  case RAW:
    if (buf == NULL) {
      unsigned char crc[3];

      crc[0] = (*all_crc & 0xFFFFFFL) >> 16;
      crc[1] = (*all_crc & 0xFFFFFFL) >> 8;
      crc[2] = (*all_crc & 0xFFFFFFL);

      ret = stream_write(crc, 1, 3, output);
    } else
      ret = stream_write(buf, 1, length, output);
    break;

  case AUTO:
  case BASE16:
    print_base16(output, buf, length, line_items, *all_crc, line, line_crc,
                 offset);
    ret = length;
    break;
  }

  return ret;
}

ssize_t output_length16(struct stream *output, enum data_type type,
                        size_t length, unsigned int line_items,
                        unsigned long *all_crc, unsigned int *line,
                        unsigned long *line_crc, unsigned int *offset) {
  unsigned char encoded[2];

  assert(length <= 65535);

  encoded[0] = length >> 8;
  encoded[1] = length;

  return output_bytes(output, type, encoded, 2, line_items, all_crc, line,
                      line_crc, offset);
}

ssize_t output_openpgp_header(struct stream *output, enum data_type type,
                              unsigned char tag, size_t length,
                              unsigned int line_items, unsigned long *all_crc,
                              unsigned int *line, unsigned long *line_crc,
                              unsigned int *offset) {
  unsigned char encoded[6];
  size_t bytes;

  /* We use the same "tag under 16, use old-style packets" rule that
     many OpenPGP programs do.  This helps make the resulting key
     byte-for-byte identical.  It's not a guarantee, as it is legal
     for the generating program to use whatever packet style it likes,
     but does help avoid questions why the input to paperkey might not
     equal the output. */

  if (tag < 16) {
    if (length > 65535) {
      encoded[0] = 0x80 | (tag << 2) | 2;
      encoded[1] = length >> 24;
      encoded[2] = length >> 16;
      encoded[3] = length >> 8;
      encoded[4] = length;
      bytes = 5;
    } else if (length > 255) {
      encoded[0] = 0x80 | (tag << 2) | 1;
      encoded[1] = length >> 8;
      encoded[2] = length;
      bytes = 3;
    } else {
      encoded[0] = 0x80 | (tag << 2);
      encoded[1] = length;
      bytes = 2;
    }
  } else {
    encoded[0] = 0xC0 | tag;

    if (length > 8383) {
      encoded[1] = 0xFF;
      encoded[2] = length >> 24;
      encoded[3] = length >> 16;
      encoded[4] = length >> 8;
      encoded[5] = length;
      bytes = 6;
    } else if (length > 191) {
      encoded[1] = 192 + ((length - 192) >> 8);
      encoded[2] = (length - 192);
      bytes = 3;
    } else {
      encoded[1] = length;
      bytes = 2;
    }
  }

  return output_bytes(output, type, encoded, bytes, line_items, all_crc, line,
                      line_crc, offset);
}

void output_finish(struct stream *output, enum data_type type,
                   unsigned int line_items, unsigned long *all_crc,
                   unsigned int *line, unsigned long *line_crc,
                   unsigned int *offset) {
  output_bytes(output, type, NULL, 0, line_items, all_crc, line, line_crc,
               offset);
}

// void set_binary_mode(FILE *stream) {
// #ifdef _WIN32
//   if (_setmode(_fileno(stream), _O_BINARY) == -1) {
//     fprintf(stderr, "Unable to set stream mode to binary: %s\n",
//             strerror(errno));
//     exit(1);
//   }
// #else
//   (void)stream;
// #endif
// }
