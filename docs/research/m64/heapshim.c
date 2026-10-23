// Shim: the 64-bit Mali blob allocates window buffers from /dev/dma_heap/*, which kernel 5.4 on the set lacks.
// Opens of /dev/dma_heap/* return a DRM fd; DMA_HEAP_IOCTL_ALLOC becomes a dumb buffer exported as a dma-buf.
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
#include <sys/stat.h>
#include <unistd.h>

struct dma_heap_allocation_data { uint64_t len; uint32_t fd; uint32_t fd_flags; uint64_t heap_flags; };
#define DMA_HEAP_IOCTL_ALLOC _IOWR('H', 0x0, struct dma_heap_allocation_data)
struct drm_mode_create_dumb { uint32_t height, width, bpp, flags, handle, pitch; uint64_t size; };
struct drm_prime_handle { uint32_t handle, flags; int32_t fd; };
struct drm_gem_close { uint32_t handle, pad; };
#define DRM_IOCTL_MODE_CREATE_DUMB _IOWR('d', 0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_PRIME_HANDLE_TO_FD _IOWR('d', 0x2d, struct drm_prime_handle)
#define DRM_IOCTL_GEM_CLOSE _IOW('d', 0x09, struct drm_gem_close)

static int heap_fds[64];
static int nheap;
static int logging = -1;
static void lg(const char *fmt, ...) {
  if (logging < 0) logging = getenv("HEAPSHIM_LOG") != NULL;
  if (!logging) return;
  va_list ap; va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap);
}
static int is_heap(const char *p) { return p && !strncmp(p, "/dev/dma_heap/", 14); }
static int is_heap_fd(int fd) { for (int i = 0; i < nheap; i++) if (heap_fds[i] == fd) return 1; return 0; }
static int open_heap(const char *p) {
  int (*real)(const char *, int, ...) = dlsym(RTLD_NEXT, "open");
  int fd = real("/dev/dri/card0", O_RDWR | O_CLOEXEC);
  if (fd >= 0 && nheap < 64) heap_fds[nheap++] = fd;
  lg("heapshim: open %s -> drm fd %d\n", p, fd);
  return fd;
}

#define OPEN_WRAP(name)                                                     \
  int name(const char *p, int fl, ...) {                                    \
    mode_t m = 0; if (fl & O_CREAT) { va_list ap; va_start(ap, fl); m = va_arg(ap, int); va_end(ap); } \
    if (is_heap(p)) return open_heap(p);                                    \
    int (*real)(const char *, int, ...) = dlsym(RTLD_NEXT, #name);          \
    return real(p, fl, m);                                                  \
  }
OPEN_WRAP(open)
OPEN_WRAP(open64)
int openat(int d, const char *p, int fl, ...) {
  mode_t m = 0; if (fl & O_CREAT) { va_list ap; va_start(ap, fl); m = va_arg(ap, int); va_end(ap); }
  if (is_heap(p)) return open_heap(p);
  int (*real)(int, const char *, int, ...) = dlsym(RTLD_NEXT, "openat");
  return real(d, p, fl, m);
}
int openat64(int d, const char *p, int fl, ...) {
  mode_t m = 0; if (fl & O_CREAT) { va_list ap; va_start(ap, fl); m = va_arg(ap, int); va_end(ap); }
  if (is_heap(p)) return open_heap(p);
  int (*real)(int, const char *, int, ...) = dlsym(RTLD_NEXT, "openat64");
  return real(d, p, fl, m);
}
int access(const char *p, int mode) {
  if (is_heap(p)) { lg("heapshim: access %s\n", p); return 0; }
  int (*real)(const char *, int) = dlsym(RTLD_NEXT, "access");
  return real(p, mode);
}

int ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req); void *arg = va_arg(ap, void *); va_end(ap);
  int (*real)(int, unsigned long, ...) = dlsym(RTLD_NEXT, "ioctl");
  if (req == DMA_HEAP_IOCTL_ALLOC && is_heap_fd(fd)) {
    struct dma_heap_allocation_data *a = arg;
    struct drm_mode_create_dumb c = {0};
    c.bpp = 32; c.width = 1024; c.height = (uint32_t)((a->len + 4095) / 4096);
    if (real(fd, DRM_IOCTL_MODE_CREATE_DUMB, &c) < 0) { lg("heapshim: create_dumb %llu failed errno %d\n", (unsigned long long)a->len, errno); return -1; }
    struct drm_prime_handle ph = {c.handle, O_RDWR | O_CLOEXEC, -1};
    int r = real(fd, DRM_IOCTL_PRIME_HANDLE_TO_FD, &ph);
    int e = errno;
    struct drm_gem_close gc = {c.handle, 0};
    real(fd, DRM_IOCTL_GEM_CLOSE, &gc);
    if (r < 0) { lg("heapshim: prime export failed errno %d\n", e); errno = e; return -1; }
    a->fd = (uint32_t)ph.fd;
    lg("heapshim: alloc %llu -> dumb %ux%u size %llu fd %d\n", (unsigned long long)a->len, c.width, c.height, (unsigned long long)c.size, ph.fd);
    return 0;
  }
  return real(fd, req, arg);
}
