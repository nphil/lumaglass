// Probe: can the 64-bit blob initialise EGL on GBM over LG's DRM nodes?
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
typedef void *EGLDisplay;
int main(int argc, char **argv) {
  void *h = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
  if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
  void *(*gbm_create_device)(int) = dlsym(h, "gbm_create_device");
  EGLDisplay (*getpd)(unsigned, void *, const intptr_t *) = dlsym(h, "eglGetPlatformDisplay");
  unsigned (*init)(EGLDisplay, int *, int *) = dlsym(h, "eglInitialize");
  int (*err)(void) = dlsym(h, "eglGetError");
  const char *(*qs)(EGLDisplay, int) = dlsym(h, "eglQueryString");
  printf("gbm_create_device=%p\n", (void *)gbm_create_device);
  const char *nodes[] = {"/dev/dri/renderD128", "/dev/dri/card0"};
  for (int i = 0; i < 2; i++) {
    int fd = open(nodes[i], O_RDWR | O_CLOEXEC);
    if (fd < 0) { printf("%s: open failed\n", nodes[i]); continue; }
    void *g = gbm_create_device ? gbm_create_device(fd) : 0;
    EGLDisplay d = getpd(0x31D7 /*GBM_KHR*/, g, 0);
    int ma = 0, mi = 0;
    unsigned ok = d && init(d, &ma, &mi);
    printf("%s: gbm=%p display=%p init=%u err=0x%x %s\n", nodes[i], g, d, ok, err(), ok ? qs(d, 0x3055) : "");
  }
  return 0;
}
