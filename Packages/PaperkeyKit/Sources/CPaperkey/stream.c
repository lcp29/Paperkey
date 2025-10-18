/*
 * Copyright (C) 2025 helmholtz <helmholtz@fomal.host>
 */

#include "stream.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

int stream_eof(const struct stream *stream) {
  return stream->pos >= stream->size ? 1 : 0;
}

int stream_getc(struct stream *stream) {
  if (stream_eof(stream))
    return EOF;
  return stream->buffer[stream->pos++];
}

void stream_revert(struct stream *stream) {
  if (stream->pos > 0)
    stream->pos--;
}

int stream_leftbyte(struct stream *stream) {
  return stream->size - stream->pos;
}

int stream_read(void *buf, size_t size, size_t nitems, struct stream *stream) {
  int items_available = (stream->size - stream->pos) / size;
  int items_count = items_available > (int)nitems ? nitems : items_available;
  memcpy(buf, stream->buffer + stream->pos, size * items_count);
  stream->pos += items_count * size;
  return items_count * size;
}

char *stream_gets(char *buf, size_t n, struct stream *stream) {
  size_t i;
  for (i = 0; i < n - 1; i++) {
    int c = stream_getc(stream);
    if (c == EOF) {
      if (i == 0)
        return NULL;
      break;
    }
    buf[i] = c;
    if (c == '\n') {
      i++;
      break;
    }
  }
  buf[i] = '\0';
  return buf;
}

struct stream *create_stream(FILE *file) {
  if (file == NULL)
    return NULL;
  struct stream *s = malloc(sizeof(struct stream));
  fseek(file, 0, SEEK_END);
  s->size = ftell(file);
  fseek(file, 0, SEEK_SET);
  s->pos = 0;
  s->buffer = malloc(s->size);
  s->memsize = s->size;
  fread(s->buffer, 1, s->size, file);
  return s;
}

int stream_printf(struct stream *stream, const char *format, ...) {
  va_list args;
  char buffer[1024];
  va_start(args, format);
  int len = vsnprintf(buffer, sizeof(buffer), format, args);
  va_end(args);
  if (len < 0 || len >= (int)sizeof(buffer))
    return -1;
  if (stream->pos + len >= stream->memsize) {
    stream->buffer = realloc(stream->buffer, 2 * (stream->pos + len));
    stream->memsize = 2 * (stream->pos + len);
  }
  if (stream->pos + len > stream->size)
    stream->size = stream->pos + len;
  memcpy(stream->buffer + stream->pos, buffer, len);
  stream->pos += len;
  return len;
}

size_t stream_write(const void *ptr, size_t size, size_t nmemb,
                    struct stream *stream) {
  int total = size * nmemb;
  if (stream->pos + total >= stream->memsize) {
    stream->buffer = realloc(stream->buffer, 2 * (stream->pos + total));
    stream->memsize = 2 * (stream->pos + total);
  }
  if (stream->pos + total > stream->size)
    stream->size = stream->pos + total;
  memcpy(stream->buffer + stream->pos, ptr, total);
  stream->pos += total;
  return nmemb;
}

struct stream *create_empty_stream(void) {
  struct stream *s = malloc(sizeof(struct stream));
  s->pos = 0;
  s->size = 0;
  s->buffer = malloc(1);
  s->memsize = 1;
  return s;
}
