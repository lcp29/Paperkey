/*
 * Copyright (C) 2025 helmholtz <helmholtz@fomal.host>
 */

#pragma once

#include <stdio.h>
#include <stdlib.h>

struct stream {
  unsigned char *buffer;
  int size;
  int pos;
  int memsize;
};

int stream_eof(const struct stream *stream);
int stream_getc(struct stream *stream);
void stream_revert(struct stream *stream);
int stream_leftbyte(struct stream *stream);
int stream_read(void *buf, size_t size, size_t items, struct stream *stream);
char *stream_gets(char *buf, size_t n, struct stream *stream);
struct stream *create_stream(FILE *file);
int stream_printf(struct stream *stream, const char *format, ...);
size_t stream_write(const void *ptr, size_t size, size_t nmemb,
                    struct stream *stream);
struct stream *create_empty_stream(void);
