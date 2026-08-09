import 'package:flutter/foundation.dart';

import '../models/app_option.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../models/property_listing_item.dart';
import '../models/saved_item.dart';
import '../models/user_profile_model.dart';
import '../services/chat_api_service.dart';
import 'session_controller.dart';

class SocialHubController extends ChangeNotifier {
  SocialHubController({
    required SessionController sessionController,
    required ChatApiService apiService,
  }) : _sessionController = sessionController,
       _apiService = apiService {
    _sessionController.addListener(_handleSessionChange);
  }

  final SessionController _sessionController;
  final ChatApiService _apiService;

  bool _initializedForSession = false;
  bool _loadingHome = false;
  bool _loadingMovies = false;
  bool _loadingMarketplace = false;
  bool _loadingJobs = false;
  bool _loadingProperties = false;
  bool _loadingUsStates = false;
  bool _submitting = false;
  String? _error;

  UserProfileModel? _profile;
  List<SavedItemModel> _bookmarks = const [];
  List<AppOption> _movieCategories = const [];
  List<MovieItem> _movies = const [];
  List<MoviePlanModel> _moviePlans = const [];
  MovieSubscriptionModel? _activeSubscription;
  List<AppOption> _marketplaceCategories = const [];
  List<AppOption> _usStates = const [];
  List<MarketplaceItem> _marketplaceItems = const [];
  List<JobListingItem> _jobItems = const [];
  List<PropertyListingItem> _propertyItems = const [];

  bool get loadingHome => _loadingHome;
  bool get loadingMovies => _loadingMovies;
  bool get loadingMarketplace => _loadingMarketplace;
  bool get loadingJobs => _loadingJobs;
  bool get loadingProperties => _loadingProperties;
  bool get loadingUsStates => _loadingUsStates;
  bool get submitting => _submitting;
  String? get error => _error;

  UserProfileModel? get profile => _profile;
  List<SavedItemModel> get bookmarks => List.unmodifiable(_bookmarks);
  List<AppOption> get movieCategories => List.unmodifiable(_movieCategories);
  List<MovieItem> get movies => List.unmodifiable(_movies);
  List<MoviePlanModel> get moviePlans => List.unmodifiable(_moviePlans);
  MovieSubscriptionModel? get activeSubscription => _activeSubscription;
  List<AppOption> get marketplaceCategories =>
      List.unmodifiable(_marketplaceCategories);
  List<AppOption> get usStates => List.unmodifiable(_usStates);
  List<MarketplaceItem> get marketplaceItems =>
      List.unmodifiable(_marketplaceItems);
  List<JobListingItem> get jobItems => List.unmodifiable(_jobItems);
  List<PropertyListingItem> get propertyItems =>
      List.unmodifiable(_propertyItems);

  Future<void> initializeIfNeeded() async {
    if (!_sessionController.isLoggedIn || _initializedForSession) return;
    _initializedForSession = true;
    await Future.wait([
      ensureUsStatesLoaded(),
      refreshHome(),
      refreshMovies(),
      refreshMarketplace(),
      refreshJobs(),
      refreshProperties(),
    ]);
  }

  Future<void> refreshHome() async {
    if (!_sessionController.isLoggedIn) return;

    _loadingHome = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _apiService.fetchProfile();
      _bookmarks = await _apiService.fetchBookmarks();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingHome = false;
      notifyListeners();
    }
  }

  Future<void> refreshMovies({int? categoryId, String? search}) async {
    if (!_sessionController.isLoggedIn) return;

    _loadingMovies = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchMovieCategories(),
        _apiService.fetchMoviePlans(),
        _apiService.fetchMovies(categoryId: categoryId, search: search),
        _apiService.fetchActiveSubscription(),
      ]);

      _movieCategories = results[0] as List<AppOption>;
      _moviePlans = results[1] as List<MoviePlanModel>;
      _movies = results[2] as List<MovieItem>;
      _activeSubscription = results[3] as MovieSubscriptionModel?;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingMovies = false;
      notifyListeners();
    }
  }

  Future<MovieItem> fetchMovieDetail(int movieId) async {
    final movie = await _apiService.fetchMovieDetail(movieId);
    final index = _movies.indexWhere((item) => item.id == movieId);
    if (index >= 0) {
      final nextMovies = List<MovieItem>.from(_movies);
      nextMovies[index] = movie;
      _movies = nextMovies;
      notifyListeners();
    }
    return movie;
  }

  Future<void> refreshMarketplace({
    bool mine = false,
    int? categoryId,
    String? state,
    String? search,
  }) async {
    if (!_sessionController.isLoggedIn) return;

    _loadingMarketplace = true;
    _error = null;
    notifyListeners();

    try {
      _marketplaceCategories = await _apiService.fetchMarketplaceCategories();
      _marketplaceItems = await _apiService.fetchMarketplace(
        mine: mine,
        categoryId: categoryId,
        state: state,
        search: search,
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingMarketplace = false;
      notifyListeners();
    }
  }

  Future<void> refreshJobs({
    bool mine = false,
    String? mode,
    String? state,
    String? search,
  }) async {
    if (!_sessionController.isLoggedIn) return;

    _loadingJobs = true;
    _error = null;
    notifyListeners();

    try {
      _jobItems = await _apiService.fetchJobs(
        mine: mine,
        mode: mode,
        state: state,
        search: search,
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingJobs = false;
      notifyListeners();
    }
  }

  Future<void> refreshProperties({
    bool mine = false,
    String? mode,
    String? state,
    String? search,
  }) async {
    if (!_sessionController.isLoggedIn) return;

    _loadingProperties = true;
    _error = null;
    notifyListeners();

    try {
      _propertyItems = await _apiService.fetchProperties(
        mine: mine,
        mode: mode,
        state: state,
        search: search,
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingProperties = false;
      notifyListeners();
    }
  }

  Future<void> subscribeToMoviePlan(int planId) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      _activeSubscription = await _apiService.subscribeToPlan(planId);
      await refreshMovies();
      await refreshHome();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> ensureUsStatesLoaded({bool force = false}) async {
    if (!_sessionController.isLoggedIn) return;
    if (_loadingUsStates) return;
    if (_usStates.isNotEmpty && !force) return;

    _loadingUsStates = true;
    _error = null;
    notifyListeners();

    try {
      _usStates = await _apiService.fetchUsStates();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingUsStates = false;
      notifyListeners();
    }
  }

  Future<void> toggleBookmark({required String type, required int id}) async {
    try {
      final saved = await _apiService.toggleBookmark(type: type, id: id);
      _bookmarks = await _apiService.fetchBookmarks();
      _marketplaceItems = _marketplaceItems
          .map(
            (item) => item.id == id && type == 'marketplace_listing'
                ? item.copyWith(saved: saved)
                : item,
          )
          .toList();
      _jobItems = _jobItems
          .map(
            (item) => item.id == id && type == 'job_listing'
                ? item.copyWith(saved: saved)
                : item,
          )
          .toList();
      _propertyItems = _propertyItems
          .map(
            (item) => item.id == id && type == 'property_listing'
                ? item.copyWith(saved: saved)
                : item,
          )
          .toList();
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createMarketplaceListing({
    required String title,
    required String description,
    required double price,
    required String city,
    required String state,
    required String contactPhone,
    required String contactEmail,
    int? categoryId,
    List<String> imageUrls = const [],
  }) async {
    await _guardedSubmit(() async {
      await _apiService.createMarketplaceListing(
        title: title,
        description: description,
        price: price,
        city: city,
        state: state,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        categoryId: categoryId,
        imageUrls: imageUrls,
      );
      await Future.wait([refreshMarketplace(mine: true), refreshHome()]);
    });
  }

  Future<void> createJobListing({
    required String title,
    required String salonName,
    required String description,
    required String requirements,
    required double salaryMin,
    required double salaryMax,
    required String city,
    required String state,
    required String contactPhone,
    required String contactEmail,
    String mode = 'hiring',
    List<String> imageUrls = const [],
  }) async {
    await _guardedSubmit(() async {
      await _apiService.createJobListing(
        title: title,
        salonName: salonName,
        description: description,
        requirements: requirements,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        city: city,
        state: state,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        mode: mode,
        imageUrls: imageUrls,
      );
      await Future.wait([refreshJobs(mine: true), refreshHome()]);
    });
  }

  Future<void> createPropertyListing({
    required String title,
    required String description,
    required double price,
    required double depositAmount,
    required String city,
    required String state,
    required String addressLine,
    required String contactPhone,
    required String contactEmail,
    required List<String> amenities,
    String mode = 'room_share',
    List<String> imageUrls = const [],
  }) async {
    await _guardedSubmit(() async {
      await _apiService.createPropertyListing(
        title: title,
        description: description,
        price: price,
        depositAmount: depositAmount,
        city: city,
        state: state,
        addressLine: addressLine,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        amenities: amenities,
        mode: mode,
        imageUrls: imageUrls,
      );
      await Future.wait([refreshProperties(mine: true), refreshHome()]);
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _guardedSubmit(Future<void> Function() action) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _handleSessionChange() {
    if (_sessionController.isLoggedIn) return;

    _initializedForSession = false;
    _profile = null;
    _bookmarks = const [];
    _movieCategories = const [];
    _movies = const [];
    _moviePlans = const [];
    _activeSubscription = null;
    _marketplaceCategories = const [];
    _usStates = const [];
    _marketplaceItems = const [];
    _jobItems = const [];
    _propertyItems = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleSessionChange);
    super.dispose();
  }
}
