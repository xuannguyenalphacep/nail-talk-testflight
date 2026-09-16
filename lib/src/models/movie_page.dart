import 'movie_item.dart';

class MoviePage {
  const MoviePage({
    required this.movies,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });

  final List<MovieItem> movies;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
}
