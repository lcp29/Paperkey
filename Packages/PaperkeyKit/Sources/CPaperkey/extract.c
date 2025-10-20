/*
 * Copyright (C) 2007, 2017 David Shaw <dshaw@jabberwocky.com>
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

#include "extract.h"
#include "config.h"
#include "output.h"
#include "packets.h"
#include "parse.h"
#include <stdio.h>

int extract(struct stream *input, struct stream *output,
            enum data_type output_type, unsigned int output_width) {
  struct packet *packet;
  int offset;
  unsigned char fingerprint[20];
  unsigned char version = 0;
  unsigned int line_items;
  unsigned long all_crc = CRC24_INIT;
  unsigned int line = 0;
  unsigned long line_crc = CRC24_INIT;
  unsigned int b16_offset = 0;

  packet = parse(input, 5, 0);
  if (!packet) {
    // fprintf(stderr, "Unable to find secret key packet\n");
    return 1;
  }

  offset = extract_secrets(packet);
  if (offset == -1)
    return 1;

  // if (verbose > 1)
  //   fprintf(stderr, "Secret offset is %d\n", offset);

  calculate_fingerprint(packet, offset, fingerprint);

  // if (verbose) {
  //   fprintf(stderr, "Primary key fingerprint: ");
  //   print_bytes(stderr, fingerprint, 20);
  //   fprintf(stderr, "\n");
  // }

  output_start(output, output_type, fingerprint, output_width, &line_items);
  output_bytes(output, output_type, &version, 1, line_items, &all_crc, &line,
               &line_crc, &b16_offset);
  output_bytes(output, output_type, packet->buf, 1, line_items, &all_crc, &line,
               &line_crc, &b16_offset);
  output_bytes(output, output_type, fingerprint, 20, line_items, &all_crc,
               &line, &line_crc, &b16_offset);
  output_length16(output, output_type, packet->len - offset, line_items,
                  &all_crc, &line, &line_crc, &b16_offset);
  output_bytes(output, output_type, &packet->buf[offset], packet->len - offset,
               line_items, &all_crc, &line, &line_crc, &b16_offset);

  free_packet(packet);

  while ((packet = parse(input, 7, 5))) {
    offset = extract_secrets(packet);
    if (offset == -1)
      return 1;

    // if (verbose > 1)
    //   fprintf(stderr, "Secret subkey offset is %d\n", offset);

    calculate_fingerprint(packet, offset, fingerprint);

    // if (verbose) {
    //   fprintf(stderr, "Subkey fingerprint: ");
    //   print_bytes(stderr, fingerprint, 20);
    //   fprintf(stderr, "\n");
    // }

    output_bytes(output, output_type, packet->buf, 1, line_items, &all_crc,
                 &line, &line_crc, &b16_offset);
    output_bytes(output, output_type, fingerprint, 20, line_items, &all_crc,
                 &line, &line_crc, &b16_offset);
    output_length16(output, output_type, packet->len - offset, line_items,
                    &all_crc, &line, &line_crc, &b16_offset);
    output_bytes(output, output_type, &packet->buf[offset],
                 packet->len - offset, line_items, &all_crc, &line, &line_crc,
                 &b16_offset);

    free_packet(packet);
  }

  output_finish(output, output_type, line_items, &all_crc, &line, &line_crc,
                &b16_offset);

  return 0;
}
