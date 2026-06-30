int main() {
  int i = 0;

loop:
  if (i >= 3)
    goto end;
  printf("i = %d\n", i);
  i++;
  goto loop;

end:
  return 0;
}
