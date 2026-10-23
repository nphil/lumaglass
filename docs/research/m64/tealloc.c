// Probe: Arm's dma-buf test exporter (/dev/dma_buf_te, held open by LG's compositor) as a buffer source.
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
struct te_version { int op, major, minor; };
struct te_alloc { uint64_t size; /* pages */ };
#define TE_BASE 'E'
#define TE_VERSION _IOR(TE_BASE, 0x00, struct te_version)
#define TE_ALLOC _IOR(TE_BASE, 0x01, struct te_alloc)
#define TE_ENQ 0x642d7465
static long meminfo(const char *key) {
  FILE *f = fopen("/proc/meminfo", "r"); char line[256]; long v = -1;
  while (fgets(line, sizeof line, f)) if (!strncmp(line, key, strlen(key))) { sscanf(line + strlen(key), " %ld", &v); break; }
  fclose(f); return v;
}
int main(void) {
  int fd = open("/dev/dma_buf_te", O_RDWR | O_CLOEXEC);
  if (fd < 0) { perror("open"); return 1; }
  struct te_version v = {TE_ENQ, 0, 0};
  int r = ioctl(fd, TE_VERSION, &v);
  printf("version rc=%d op=0x%x %d.%d\n", r, v.op, v.major, v.minor);
  printf("before: CmaFree %ld kB, MemFree %ld kB\n", meminfo("CmaFree:"), meminfo("MemFree:"));
  int bufs[32], n = 0;
  for (; n < 12; n++) {
    struct te_alloc a = {(1920 * 1080 * 4 + 4095) / 4096};
    int b = ioctl(fd, TE_ALLOC, &a);
    if (b < 0) { perror("alloc"); break; }
    bufs[n] = b;
    if (n == 0) {
      void *p = mmap(0, a.size * 4096, PROT_READ | PROT_WRITE, MAP_SHARED, b, 0);
      printf("first fd=%d mmap=%s\n", b, p == MAP_FAILED ? "failed" : "ok");
      if (p != MAP_FAILED) { memset(p, 0x5a, 4096); munmap(p, a.size * 4096); }
    }
  }
  printf("after %d buffers: CmaFree %ld kB, MemFree %ld kB\n", n, meminfo("CmaFree:"), meminfo("MemFree:"));
  for (int i = 0; i < n; i++) close(bufs[i]);
  printf("freed: CmaFree %ld kB, MemFree %ld kB\n", meminfo("CmaFree:"), meminfo("MemFree:"));
  return 0;
}
