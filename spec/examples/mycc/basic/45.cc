void modify_ptr(const char **p) { (*p)++; }

void modify_ptr2(const char **p) { ++(*p); }

void modify_ptr3(const char **p) { *p = *p + 1; }

int main() {
  const char *str = "abcdefg";
  printf("before: %c\n", *str);
  modify_ptr(&str);
  printf("after: %c\n", *str);
  modify_ptr2(&str);
  printf("after: %c\n", *str);
  modify_ptr3(&str);
  printf("after: %c\n", *str);
  return 0;
}
