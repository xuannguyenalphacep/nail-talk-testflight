import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_option.dart';
import '../models/clinic_item.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/movie_page.dart';
import '../models/movie_plan_model.dart';
import '../models/property_listing_item.dart';
import '../models/saved_item.dart';
import '../models/service_category.dart';
import '../models/user_profile_model.dart';
import '../core/localization/app_localizer.dart';
import '../core/utils/content_moderation_utils.dart';
import '../services/chat_api_service.dart';
import '../core/constants/app_constants.dart';
import 'session_controller.dart';

class SocialHubController extends ChangeNotifier {
  static const int _moviePageSize = 10;

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
  bool _loadingMoreMovies = false;
  bool _loadingMarketplace = false;
  bool _loadingJobs = false;
  bool _loadingProperties = false;
  bool _loadingServices = false;
  bool _loadingClinics = false;
  bool _loadingUsStates = false;
  bool _submitting = false;
  String? _error;

  UserProfileModel? _profile;
  List<SavedItemModel> _bookmarks = const [];
  List<AppOption> _movieCategories = const [];
  List<MovieItem> _movies = const [];
  int _moviePage = 0;
  int _movieLastPage = 1;
  int? _movieCategoryId;
  String? _movieSearch;
  List<MoviePlanModel> _moviePlans = const [];
  MovieSubscriptionModel? _activeSubscription;
  List<AppOption> _marketplaceCategories = const [];
  List<AppOption> _usStates = const [];
  List<MarketplaceItem> _marketplaceItems = const [];
  List<JobListingItem> _jobItems = const [];
  List<PropertyListingItem> _propertyItems = const [];
  List<ServiceCategory> _serviceCategories = const [];
  List<AppOption> _clinicSpecialties = const [];
  List<ClinicItem> _clinicItems = const [];

  bool get loadingHome => _loadingHome;
  bool get loadingMovies => _loadingMovies;
  bool get loadingMoreMovies => _loadingMoreMovies;
  bool get loadingMarketplace => _loadingMarketplace;
  bool get loadingJobs => _loadingJobs;
  bool get loadingProperties => _loadingProperties;
  bool get loadingServices => _loadingServices;
  bool get loadingClinics => _loadingClinics;
  bool get loadingUsStates => _loadingUsStates;
  bool get submitting => _submitting;
  String? get error => _error;

  UserProfileModel? get profile => _profile;
  List<SavedItemModel> get bookmarks => List.unmodifiable(_bookmarks);
  List<AppOption> get movieCategories => List.unmodifiable(_movieCategories);
  List<MovieItem> get movies => List.unmodifiable(_movies);
  bool get hasMoreMovies => _moviePage < _movieLastPage;
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
  List<ServiceCategory> get serviceCategories =>
      List.unmodifiable(_serviceCategories);
  List<AppOption> get clinicSpecialties =>
      List.unmodifiable(_clinicSpecialties);
  List<ClinicItem> get clinicItems => List.unmodifiable(_clinicItems);
  bool get _hasSelectedService => _sessionController.selectedApp != null;
  bool get _isLoggedIn => _sessionController.isLoggedIn;

  Future<void> initializeIfNeeded() async {
    if (!_hasSelectedService || _initializedForSession) return;
    _initializedForSession = true;
    await Future.wait([
      ensureUsStatesLoaded(),
      refreshHome(),
      refreshMovies(),
      refreshMarketplace(),
      refreshJobs(),
      refreshProperties(),
      refreshServices(),
    ]);
  }

  Future<void> refreshHome() async {
    if (!_hasSelectedService) return;

    _loadingHome = true;
    _error = null;
    notifyListeners();

    try {
      if (_isLoggedIn) {
        _profile = await _apiService.fetchProfile();
        _bookmarks = await _apiService.fetchBookmarks();
      } else {
        _profile = null;
        _bookmarks = const [];
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingHome = false;
      notifyListeners();
    }
  }

  Future<void> refreshMovies({int? categoryId, String? search}) async {
    if (!_hasSelectedService) return;
    if (_loadingMovies) return;

    _loadingMovies = true;
    _loadingMoreMovies = false;
    _movieCategoryId = categoryId;
    _movieSearch = search;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchMovieCategories(),
        AppConstants.moviePaymentsEnabled && _isLoggedIn
            ? _apiService.fetchMoviePlans()
            : Future.value(<MoviePlanModel>[]),
        _apiService.fetchMovies(
          categoryId: categoryId,
          search: search,
          page: 1,
          perPage: _moviePageSize,
        ),
        AppConstants.moviePaymentsEnabled && _isLoggedIn
            ? _apiService.fetchActiveSubscription()
            : Future.value(null),
      ]);
      final moviePage = results[2] as MoviePage;

      _movieCategories = results[0] as List<AppOption>;
      _moviePlans = results[1] as List<MoviePlanModel>;
      _movies = moviePage.movies;
      _moviePage = moviePage.currentPage;
      _movieLastPage = moviePage.lastPage;
      _activeSubscription = results[3] as MovieSubscriptionModel?;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingMovies = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMovies() async {
    if (!_hasSelectedService ||
        _loadingMovies ||
        _loadingMoreMovies ||
        !hasMoreMovies) {
      return;
    }

    _loadingMoreMovies = true;
    _error = null;
    notifyListeners();

    try {
      final moviePage = await _apiService.fetchMovies(
        categoryId: _movieCategoryId,
        search: _movieSearch,
        page: _moviePage + 1,
        perPage: _moviePageSize,
      );
      final seenIds = _movies.map((movie) => movie.id).toSet();
      _movies = [
        ..._movies,
        ...moviePage.movies.where((movie) => seenIds.add(movie.id)),
      ];
      _moviePage = moviePage.currentPage;
      _movieLastPage = moviePage.lastPage;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingMoreMovies = false;
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
    if (!_hasSelectedService) return;

    _loadingMarketplace = true;
    _error = null;
    notifyListeners();

    try {
      _marketplaceCategories = await _apiService.fetchMarketplaceCategories();
      _marketplaceItems = await _apiService.fetchMarketplace(
        mine: _isLoggedIn && mine,
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
    if (!_hasSelectedService) return;

    _loadingJobs = true;
    _error = null;
    notifyListeners();

    try {
      _jobItems = await _apiService.fetchJobs(
        mine: _isLoggedIn && mine,
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
    if (!_hasSelectedService) return;

    _loadingProperties = true;
    _error = null;
    notifyListeners();

    try {
      _propertyItems = await _apiService.fetchProperties(
        mine: _isLoggedIn && mine,
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

  Future<void> refreshClinics({
    String? serviceSlug,
    String? province,
    String? specialty,
    String? search,
  }) async {
    if (!_hasSelectedService) return;

    _loadingClinics = true;
    _clinicSpecialties = const [];
    _clinicItems = const [];
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchClinicSpecialties(serviceSlug: serviceSlug),
        _apiService.fetchClinics(
          serviceSlug: serviceSlug,
          province: province,
          specialty: specialty,
          search: search,
        ),
      ]);
      _clinicSpecialties = results[0] as List<AppOption>;
      _clinicItems = results[1] as List<ClinicItem>;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingClinics = false;
      notifyListeners();
    }
  }

  Future<void> refreshServices() async {
    if (!_hasSelectedService) return;

    _loadingServices = true;
    _error = null;
    notifyListeners();

    try {
      _serviceCategories = await _apiService.fetchServiceCategories();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingServices = false;
      notifyListeners();
    }
  }

  Future<ClinicItem> fetchClinicDetail(int clinicId) async {
    final clinic = await _apiService.fetchClinicDetail(clinicId);
    final index = _clinicItems.indexWhere((item) => item.id == clinicId);
    if (index >= 0) {
      final nextClinics = List<ClinicItem>.from(_clinicItems);
      nextClinics[index] = clinic;
      _clinicItems = nextClinics;
      notifyListeners();
    }
    return clinic;
  }

  Future<void> subscribeToMoviePlan(int planId) async {
    _requireLogin();

    if (!AppConstants.moviePaymentsEnabled) {
      _error = AppConstants.noPaymentReviewNote;
      notifyListeners();
      return;
    }

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
    if (!_hasSelectedService) return;
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
    _requireLogin();

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
    ContentModerationUtils.validateOrThrow([title, description]);
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
    ContentModerationUtils.validateOrThrow([
      title,
      salonName,
      description,
      requirements,
    ]);
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
    String mode = 'rent_out',
    List<String> imageUrls = const [],
  }) async {
    ContentModerationUtils.validateOrThrow([title, description, addressLine]);
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

  Future<ClinicBookingResult> submitClinicBooking({
    required int clinicId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String currentLocation,
    required String plannedTravelDate,
    required String appointmentDate,
    required String preferredTime,
    required String specialty,
    required String message,
  }) async {
    ContentModerationUtils.validateOrThrow([
      customerName,
      currentLocation,
      specialty,
      message,
    ]);

    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.submitClinicBooking(
        clinicId: clinicId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        currentLocation: currentLocation,
        plannedTravelDate: plannedTravelDate,
        appointmentDate: appointmentDate,
        preferredTime: preferredTime,
        specialty: specialty,
        message: message,
      );
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> reportContent({
    required String type,
    required int id,
    required String reason,
    String? description,
  }) async {
    _requireLogin();

    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.reportContent(
        type: type,
        id: id,
        reason: reason,
        description: description,
      );
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _guardedSubmit(Future<void> Function() action) async {
    _requireLogin();

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

  void _requireLogin() {
    if (_isLoggedIn) return;
    _error = AppLocalizer.current.tr('Please sign in to continue.');
    notifyListeners();
    throw StateError(_error!);
  }

  void _handleSessionChange() {
    _initializedForSession = false;

    if (_sessionController.isLoggedIn) {
      unawaited(initializeIfNeeded());
      return;
    }

    _profile = null;
    _bookmarks = const [];
    _moviePlans = const [];
    _activeSubscription = null;
    if (!_hasSelectedService) {
      _movieCategories = const [];
      _movies = const [];
      _loadingMoreMovies = false;
      _moviePage = 0;
      _movieLastPage = 1;
      _movieCategoryId = null;
      _movieSearch = null;
      _marketplaceCategories = const [];
      _usStates = const [];
      _marketplaceItems = const [];
      _jobItems = const [];
      _propertyItems = const [];
      _serviceCategories = const [];
      _clinicSpecialties = const [];
      _clinicItems = const [];
    } else {
      unawaited(initializeIfNeeded());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleSessionChange);
    super.dispose();
  }
}
