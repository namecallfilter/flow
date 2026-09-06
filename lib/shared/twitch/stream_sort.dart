enum StreamSort {
  recommendedForYou("Recommended For You"),
  viewersHighToLow("Viewers: High to Low"),
  viewersLowToHigh("Viewers: Low to High"),
  recentlyStarted("Recently Started");

  const StreamSort(this.label);

  final String label;
}

enum CategorySort {
  recommendedForYou("Recommended For You"),
  viewersHighToLow("Viewers: High to Low");

  const CategorySort(this.label);

  final String label;
}
