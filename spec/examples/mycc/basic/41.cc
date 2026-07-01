int main() {
	int x[] = {1, 2, 3, 4, 5};
	printf("%d\n", (&x[4]) - (x + 1));
	return 0;
}