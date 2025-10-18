/*
 * paperkeytest.c - Test file for paperkey roundtrip functionality
 */

#include "config.h"
#include "extract.h"
#include "output.h"
#include "restore.h"
#include "stream.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

int main(void) {
  const char *types[] = {"rsa", "dsaelg", "ecc", "eddsa"};
  int num_types = sizeof(types) / sizeof(types[0]);

  for (int i = 0; i < num_types; i++) {
    const char *type = types[i];
    char sec_path[256];
    char pub_path[256];

    sprintf(sec_path, "checks/papertest-%s.sec", type);
    sprintf(pub_path, "checks/papertest-%s.pub", type);

    // Open and read secret key
    FILE *sec_file = fopen(sec_path, "rb");
    if (!sec_file) {
      fprintf(stderr, "Unable to open %s: %s\n", sec_path, strerror(errno));
      exit(1);
    }
    struct stream *sec_stream = create_stream(sec_file);
    fclose(sec_file);

    // Open and read public key
    FILE *pub_file = fopen(pub_path, "rb");
    if (!pub_file) {
      fprintf(stderr, "Unable to open %s: %s\n", pub_path, strerror(errno));
      exit(1);
    }
    struct stream *pub_stream = create_stream(pub_file);
    fclose(pub_file);

    // Test raw binary format
    struct stream *extracted_raw = create_empty_stream();
    if (extract(sec_stream, extracted_raw, RAW, 78) != 0) {
      exit(1);
    }
    extracted_raw->pos = 0;
    struct stream *restored_raw = create_empty_stream();
    if (restore(pub_stream, extracted_raw, RAW, restored_raw, 0) != 0) {
      exit(1);
    }
    if (restored_raw->size != sec_stream->size ||
        memcmp(restored_raw->buffer, sec_stream->buffer, sec_stream->size) !=
            0) {
      exit(1);
    }
    free(extracted_raw->buffer);
    free(extracted_raw);
    free(restored_raw->buffer);
    free(restored_raw);

    // Test base16 text format
    sec_stream->pos = 0;
    pub_stream->pos = 0;
    struct stream *extracted_b16 = create_empty_stream();
    if (extract(sec_stream, extracted_b16, BASE16, 78) != 0) {
      exit(1);
    }
    extracted_b16->pos = 0;
    struct stream *restored_b16 = create_empty_stream();
    if (restore (pub_stream, extracted_b16, BASE16, restored_b16, 0) != 0) {
      exit(1);
    }
    if (restored_b16->size != sec_stream->size ||
        memcmp(restored_b16->buffer, sec_stream->buffer, sec_stream->size) !=
            0) {
      exit(1);
    }
    free(extracted_b16->buffer);
    free(extracted_b16);
    free(restored_b16->buffer);
    free(restored_b16);

    // Clean up
    free(sec_stream->buffer);
    free(sec_stream);
    free(pub_stream->buffer);
    free(pub_stream);

    printf("%s ", type);
  }

  printf("\n");
  return 0;
}
