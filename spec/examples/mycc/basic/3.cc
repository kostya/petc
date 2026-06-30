int check1() {
  if (1)
    return 1;
}
int check2() {
  if (1) {
    return 2;
  }
}
int check3() {
  int a;
  if (1)
    a = 2;
  return a;
}
int check4() {
  if (1)
    printf("4 called\n");
  return 0;
}
int check5() {
  if (1)
    if (1)
      printf("5 called\n");
  return 0;
}

int main() {
  printf("check1 %d\n", check1());
  printf("check2 %d\n", check2());
  printf("check3 %d\n", check3());
  printf("check4 %d\n", check4());
  printf("check5 %d\n", check5());
  return 0;
}
