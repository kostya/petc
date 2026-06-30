void bla(int x) {
  x++;
  printf("x = %d\n", x);

  x += 10;
  printf("x = %d\n", x);

  x = 255 - x;
  printf("x = %d\n", x);
}

int main() {
  bla(10);
  return 0;
}
