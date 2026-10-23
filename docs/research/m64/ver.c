#include <stdio.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdint.h>
struct vc { uint16_t major, minor; };
int main(void) {
  int fd = open("/dev/mali0", O_RDWR | O_CLOEXEC);
  if (fd < 0) { perror("open /dev/mali0"); return 1; }
  for (int m = 10; m <= 12; m++) {
    struct vc v = { m, 0 };
    int r = ioctl(fd, 0xC0048000, &v);
    printf("ask %d.0 -> rc=%d kernel says %u.%u\n", m, r, v.major, v.minor);
    if (r == 0) break;
  }
  close(fd); return 0;
}
