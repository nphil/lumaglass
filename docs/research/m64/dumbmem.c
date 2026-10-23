// Probe: where do lg1k dumb buffers come from (CMA or ordinary pages), and how many 1080p buffers fit?
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
struct drm_mode_create_dumb { uint32_t height, width, bpp, flags, handle, pitch; uint64_t size; };
struct drm_gem_close { uint32_t handle, pad; };
#define DRM_IOCTL_MODE_CREATE_DUMB _IOWR('d', 0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_GEM_CLOSE _IOW('d', 0x09, struct drm_gem_close)
static long meminfo(const char *key) {
  FILE *f = fopen("/proc/meminfo", "r"); char line[256]; long v = -1;
  while (fgets(line, sizeof line, f)) if (!strncmp(line, key, strlen(key))) { sscanf(line + strlen(key), " %ld", &v); break; }
  fclose(f); return v;
}
int main(void) {
  int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
  printf("before: CmaFree %ld kB, MemFree %ld kB, CmaTotal %ld kB\n", meminfo("CmaFree:"), meminfo("MemFree:"), meminfo("CmaTotal:"));
  uint32_t h[64]; int n = 0;
  for (; n < 24; n++) {
    struct drm_mode_create_dumb c = {1080, 1920, 32, 0, 0, 0, 0};
    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &c) < 0) { perror("create_dumb"); break; }
    h[n] = c.handle;
    if (n == 0 || n == 5 || n == 11 || n == 23)
      printf("after %2d buffers (8.3 MB each): CmaFree %ld kB, MemFree %ld kB\n", n + 1, meminfo("CmaFree:"), meminfo("MemFree:"));
  }
  for (int i = 0; i < n; i++) { struct drm_gem_close g = {h[i], 0}; ioctl(fd, DRM_IOCTL_GEM_CLOSE, &g); }
  printf("freed: CmaFree %ld kB, MemFree %ld kB\n", meminfo("CmaFree:"), meminfo("MemFree:"));
  return 0;
}
