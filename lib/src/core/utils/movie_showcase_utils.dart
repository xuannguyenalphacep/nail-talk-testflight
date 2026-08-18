import 'package:flutter/material.dart';

import '../../models/movie_item.dart';
import '../../widgets/metro_ui.dart';

class MovieCastMember {
  const MovieCastMember({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;
}

class MovieShowcaseMeta {
  const MovieShowcaseMeta({
    required this.year,
    required this.durationMinutes,
    required this.rating,
    required this.reviewCount,
    required this.popularityScore,
    required this.isNew,
    required this.isHd,
    required this.tags,
    required this.cast,
  });

  final int year;
  final int durationMinutes;
  final double rating;
  final int reviewCount;
  final int popularityScore;
  final bool isNew;
  final bool isHd;
  final List<String> tags;
  final List<MovieCastMember> cast;
}

MovieShowcaseMeta movieShowcaseMeta(MovieItem movie) {
  switch (movie.slug) {
    case 'cosmos-laundromat-first-cycle':
      return const MovieShowcaseMeta(
        year: 2022,
        durationMinutes: 125,
        rating: 8.5,
        reviewCount: 2400,
        popularityScore: 98,
        isNew: true,
        isHd: true,
        tags: ['Romance', 'Drama', 'Fantasy'],
        cast: [
          MovieCastMember(
            name: 'Lena Truong',
            avatarUrl: 'https://i.pravatar.cc/300?img=41',
          ),
          MovieCastMember(
            name: 'David Huynh',
            avatarUrl: 'https://i.pravatar.cc/300?img=12',
          ),
          MovieCastMember(
            name: 'Mina Le',
            avatarUrl: 'https://i.pravatar.cc/300?img=29',
          ),
          MovieCastMember(
            name: 'Aron Pham',
            avatarUrl: 'https://i.pravatar.cc/300?img=15',
          ),
        ],
      );
    case 'caminandes-llamigos':
      return const MovieShowcaseMeta(
        year: 2021,
        durationMinutes: 108,
        rating: 8.2,
        reviewCount: 1800,
        popularityScore: 92,
        isNew: false,
        isHd: true,
        tags: ['Comedy', 'Adventure'],
        cast: [
          MovieCastMember(
            name: 'Rafa Torres',
            avatarUrl: 'https://i.pravatar.cc/300?img=52',
          ),
          MovieCastMember(
            name: 'Emma Cao',
            avatarUrl: 'https://i.pravatar.cc/300?img=37',
          ),
          MovieCastMember(
            name: 'Jules Tran',
            avatarUrl: 'https://i.pravatar.cc/300?img=47',
          ),
          MovieCastMember(
            name: 'Nico Phan',
            avatarUrl: 'https://i.pravatar.cc/300?img=61',
          ),
        ],
      );
    case 'sintel':
      return const MovieShowcaseMeta(
        year: 2020,
        durationMinutes: 112,
        rating: 8.1,
        reviewCount: 2100,
        popularityScore: 88,
        isNew: false,
        isHd: true,
        tags: ['Fantasy', 'Drama'],
        cast: [
          MovieCastMember(
            name: 'Sora Nguyen',
            avatarUrl: 'https://i.pravatar.cc/300?img=33',
          ),
          MovieCastMember(
            name: 'Ken Do',
            avatarUrl: 'https://i.pravatar.cc/300?img=14',
          ),
          MovieCastMember(
            name: 'Aiko Lam',
            avatarUrl: 'https://i.pravatar.cc/300?img=49',
          ),
          MovieCastMember(
            name: 'Mika Bui',
            avatarUrl: 'https://i.pravatar.cc/300?img=57',
          ),
        ],
      );
    case 'tears-of-steel':
      return const MovieShowcaseMeta(
        year: 2019,
        durationMinutes: 136,
        rating: 7.9,
        reviewCount: 1600,
        popularityScore: 84,
        isNew: false,
        isHd: true,
        tags: ['Sci-Fi', 'Action'],
        cast: [
          MovieCastMember(
            name: 'Tina Vo',
            avatarUrl: 'https://i.pravatar.cc/300?img=23',
          ),
          MovieCastMember(
            name: 'Marco Tran',
            avatarUrl: 'https://i.pravatar.cc/300?img=19',
          ),
          MovieCastMember(
            name: 'Selena Nguyen',
            avatarUrl: 'https://i.pravatar.cc/300?img=25',
          ),
          MovieCastMember(
            name: 'Ryan Le',
            avatarUrl: 'https://i.pravatar.cc/300?img=67',
          ),
        ],
      );
  }

  final hash = movie.title.codeUnits.fold<int>(
    movie.id * 17,
    (value, code) => value + code,
  );
  final baseYear = 2018 + (hash % 6);
  final duration = 92 + (hash % 38);
  final rating = 74 + (hash % 18);
  final reviews = 900 + ((hash % 16) * 140);
  final avatars = List<String>.generate(
    4,
    (index) => 'https://i.pravatar.cc/300?img=${(hash + index * 7) % 70 + 1}',
  );
  const names = [
    'Lina Tran',
    'Mason Le',
    'Ari Pham',
    'Bella Nguyen',
    'Noah Vo',
    'Mia Dang',
  ];

  return MovieShowcaseMeta(
    year: baseYear,
    durationMinutes: duration,
    rating: rating / 10,
    reviewCount: reviews,
    popularityScore: 72 + (hash % 25),
    isNew: hash.isEven,
    isHd: true,
    tags: [
      if (movie.category?.name.trim().isNotEmpty == true) movie.category!.name,
      if (movie.accessType == 'free') 'Community stream' else 'Premium shelf',
    ],
    cast: List<MovieCastMember>.generate(
      4,
      (index) => MovieCastMember(
        name: names[(hash + index) % names.length],
        avatarUrl: avatars[index],
      ),
    ),
  );
}

String movieDurationLabel(int durationMinutes) {
  final hours = durationMinutes ~/ 60;
  final minutes = durationMinutes % 60;
  return hours <= 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

String movieReviewLabel(int reviewCount) {
  if (reviewCount >= 1000) {
    final compact = reviewCount / 1000;
    final digits = reviewCount % 1000 == 0 ? 0 : 1;
    return '${compact.toStringAsFixed(digits)}k';
  }
  return '$reviewCount';
}

IconData movieCategoryIcon(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('ready')) return Icons.play_circle_rounded;
  if (lower.contains('document')) return Icons.folder_rounded;
  if (lower.contains('comedy')) return Icons.sentiment_satisfied_rounded;
  if (lower.contains('action')) return Icons.movie_filter_rounded;
  if (lower.contains('romance')) return Icons.favorite_rounded;
  if (lower.contains('horror')) return Icons.nightlight_round_rounded;
  if (lower.contains('animation')) return Icons.pets_rounded;
  if (lower.contains('fantasy')) return Icons.auto_awesome_rounded;
  if (lower.contains('sci')) return Icons.rocket_launch_rounded;
  return Icons.apps_rounded;
}

Color movieCategoryTint(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('ready')) return kMetroCoral;
  if (lower.contains('document')) return const Color(0xFF6C74D9);
  if (lower.contains('comedy')) return const Color(0xFFF3BF43);
  if (lower.contains('action')) return const Color(0xFF6FA2D6);
  if (lower.contains('romance')) return const Color(0xFFF56B97);
  if (lower.contains('horror')) return const Color(0xFF8B67D8);
  if (lower.contains('animation')) return const Color(0xFF79BF5C);
  if (lower.contains('fantasy')) return const Color(0xFF68C7D7);
  if (lower.contains('sci')) return const Color(0xFF6B8BFF);
  return const Color(0xFF9DA5BC);
}
