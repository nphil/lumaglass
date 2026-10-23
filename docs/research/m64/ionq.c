// Probe: list ION heaps and try a 1080p allocation from each.
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
struct ion_allocation_data { uint64_t len; uint32_t heap_id_mask, flags, fd, unused; };
struct ion_heap_data { char name[32]; uint32_t type, heap_id, r0, r1, r2; };
struct ion_heap_query { uint32_t cnt, r0; uint64_t heaps; uint32_t r1, r2; };
#define ION_IOC_ALLOC _IOWR('I', 0, struct ion_allocation_data)
#define ION_IOC_HEAP_QUERY _IOWR('I', 8, struct ion_heap_query)
int main(void) {
  int fd = open("/dev/ion", O_RDWR | O_CLOEXEC);
  if (fd < 0) { perror("open ion"); return 1; }
  struct ion_heap_data hd[32]; memset(hd, 0, sizeof hd);
  struct ion_heap_query q = {32, 0, (uint64_t)(uintptr_t)hd, 0, 0};
  if (ioctl(fd, ION_IOC_HEAP_QUERY, &q) < 0) { perror("heap query"); return 2; }
  printf("%u heaps\n", q.cnt);
  for (unsigned i = 0; i < q.cnt; i++) {
    struct ion_allocation_data a = {1920 * 1080 * 4, 1u << hd[i].heap_id, 0, 0, 0};
    int r = ioctl(fd, ION_IOC_ALLOC, &a);
    void *p = r == 0 ? mmap(0, a.len, PROT_READ | PROT_WRITE, MAP_SHARED, a.fd, 0) : MAP_FAILED;
    printf("heap id=%u type=%u name=%s alloc=%d fd=%d mmap=%s\n", hd[i].heap_id, hd[i].type, hd[i].name, r, r == 0 ? (int)a.fd : -1,
           p != MAP_FAILED ? "ok" : "no");
    if (p != MAP_FAILED) munmap(p, a.len);
    if (r == 0) close(a.fd);
  }
  return 0;
}
