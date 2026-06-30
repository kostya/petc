int test(int limit) {
  int xargs_flag = 0, xargs_buf = 0, offset = 0, count = 0;
  int x = 0, z = 0, last = 0, i = 0;

  while (1) {
    x = i + 1;
    if (x % 2 == 0) {
      if (xargs_flag == 1) {
        xargs_flag = 0;
        z = xargs_buf + x;
        if (offset >= 5) {
          if (count < limit) {
            last = z;
            count++;
          } else {
            break;
          }
        } else {
          offset++;
        }
      } else {
        xargs_flag = 1;
        xargs_buf = x;
      }
    }
    i++;
  }
  return last;
}

int main() {
  printf("%d\n", test(100000000));
  return 0;
}
