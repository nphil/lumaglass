// Shim: the 64-bit Mali blob allocates window buffers from /dev/dma_heap/*, which kernel 5.4 on the set lacks.
// "system*" heaps are served by Arm's dma-buf test exporter (/dev/dma_buf_te), the allocator LG's compositor itself
// holds open: ordinary pages mapped through the GPU's MMU, so no contiguous (CMA) memory is needed. With about
// 50-65 MB of CMA free, a second 1080p DRM dumb buffer already failed. The protected heap is reported missing.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

struct dma_heap_allocation_data { uint64_t len; uint32_t fd; uint32_t fd_flags; uint64_t heap_flags; };
#define DMA_HEAP_IOCTL_ALLOC _IOWR('H', 0x0, struct dma_heap_allocation_data)
struct te_alloc { uint64_t pages; };
#define TE_ALLOC _IOR('E', 0x01, struct te_alloc)

static int (*real_open)(const char *, int, ...);
static int (*real_open64)(const char *, int, ...);
static int (*real_openat)(int, const char *, int, ...);
static int (*real_openat64)(int, const char *, int, ...);
static int (*real_access)(const char *, int);
static int (*real_ioctl)(int, unsigned long, ...);
static int logging;
static volatile int heap_fds[16];

__attribute__((constructor)) static void init(void) {
  real_open = dlsym(RTLD_NEXT, "open");
  real_open64 = dlsym(RTLD_NEXT, "open64");
  real_openat = dlsym(RTLD_NEXT, "openat");
  real_openat64 = dlsym(RTLD_NEXT, "openat64");
  real_access = dlsym(RTLD_NEXT, "access");
  real_ioctl = dlsym(RTLD_NEXT, "ioctl");
  logging = getenv("HEAPSHIM_LOG") != NULL;
  for (int i = 0; i < 16; i++) heap_fds[i] = -1;
}

static int is_heap(const char *p) { return p && !strncmp(p, "/dev/dma_heap/", 14); }
static int is_heap_fd(int fd) {
  for (int i = 0; i < 16; i++) if (heap_fds[i] == fd) return 1;
  return 0;
}
static int open_heap(const char *p) {
  if (strncmp(p + 14, "system", 6)) { errno = ENOENT; return -1; }
  int fd = real_open("/dev/dma_buf_te", O_RDWR | O_CLOEXEC);
  for (int i = 0; fd >= 0 && i < 16; i++)
    if (__sync_bool_compare_and_swap(&heap_fds[i], -1, fd)) break;
  if (logging) fprintf(stderr, "heapshim: open %s -> dma_buf_te fd %d\n", p, fd);
  return fd;
}

static mode_t mode_arg(int fl, va_list ap) { return (fl & (O_CREAT | O_TMPFILE)) ? (mode_t)va_arg(ap, int) : 0; }
int open(const char *p, int fl, ...) {
  va_list ap; va_start(ap, fl); mode_t m = mode_arg(fl, ap); va_end(ap);
  return is_heap(p) ? open_heap(p) : real_open(p, fl, m);
}
int open64(const char *p, int fl, ...) {
  va_list ap; va_start(ap, fl); mode_t m = mode_arg(fl, ap); va_end(ap);
  return is_heap(p) ? open_heap(p) : real_open64(p, fl, m);
}
int openat(int d, const char *p, int fl, ...) {
  va_list ap; va_start(ap, fl); mode_t m = mode_arg(fl, ap); va_end(ap);
  return is_heap(p) ? open_heap(p) : real_openat(d, p, fl, m);
}
int openat64(int d, const char *p, int fl, ...) {
  va_list ap; va_start(ap, fl); mode_t m = mode_arg(fl, ap); va_end(ap);
  return is_heap(p) ? open_heap(p) : real_openat64(d, p, fl, m);
}
int access(const char *p, int mode) {
  if (is_heap(p)) { if (!strncmp(p + 14, "system", 6)) return 0; errno = ENOENT; return -1; }
  return real_access(p, mode);
}
int close(int fd) {
  static int (*real_close)(int);
  if (!real_close) real_close = dlsym(RTLD_NEXT, "close");
  for (int i = 0; i < 16; i++) if (heap_fds[i] == fd) __sync_bool_compare_and_swap(&heap_fds[i], fd, -1);
  return real_close(fd);
}

int ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req); void *arg = va_arg(ap, void *); va_end(ap);
  if (req != DMA_HEAP_IOCTL_ALLOC || !is_heap_fd(fd)) return real_ioctl(fd, req, arg);
  struct dma_heap_allocation_data *a = arg;
  struct te_alloc t = {(a->len + 4095) / 4096};
  int b = real_ioctl(fd, TE_ALLOC, &t);
  if (logging) fprintf(stderr, "heapshim: alloc %llu bytes -> fd %d\n", (unsigned long long)a->len, b);
  if (b < 0) return -1;
  a->fd = (uint32_t)b;
  return 0;
}
