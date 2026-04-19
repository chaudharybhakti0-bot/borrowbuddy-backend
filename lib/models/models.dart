// ─── User Model ───────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String college;
  final String? avatar;
  final bool verified;
  final double rating;
  final int listed;
  final int bookings;
  final int reviewsCount;
  final List<String> savedItems;
  final String createdAt;

  UserModel({
    required this.id, required this.name, required this.email,
    required this.phone, required this.college, this.avatar,
    required this.verified, required this.rating, required this.listed,
    required this.bookings, required this.reviewsCount,
    required this.savedItems, required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    college: json['college'] ?? '',
    avatar: json['avatar'],
    verified: json['verified'] ?? false,
    rating: (json['rating'] ?? 0).toDouble(),
    listed: json['listed'] ?? 0,
    bookings: json['bookings'] ?? 0,
    reviewsCount: json['reviews_count'] ?? 0,
    savedItems: List<String>.from(json['saved_items'] ?? []),
    createdAt: json['created_at'] ?? '',
  );

  UserModel copyWith({String? name, String? phone, String? college, String? avatar}) => UserModel(
    id: id, name: name ?? this.name, email: email,
    phone: phone ?? this.phone, college: college ?? this.college,
    avatar: avatar ?? this.avatar, verified: verified, rating: rating,
    listed: listed, bookings: bookings, reviewsCount: reviewsCount,
    savedItems: savedItems, createdAt: createdAt,
  );
}

// ─── Item Model ───────────────────────────────────────────────────────────────
class ItemModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final bool ownerVerified;
  final double ownerRating;
  final String name;
  final String category;
  final String description;
  final String brand;
  final String? size;
  final String? color;
  final String condition;
  final double pricePerDay;
  final double deposit;
  final int minDays;
  final int maxDays;
  final double lateFee;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final bool available;
  final List<BookedDateRange> bookedDates;
  final List<ReviewModel> reviews;
  final String createdAt;

  ItemModel({
    required this.id, required this.ownerId, this.ownerName = '',
    this.ownerVerified = false, this.ownerRating = 0,
    required this.name, required this.category, required this.description,
    required this.brand, this.size, this.color, required this.condition,
    required this.pricePerDay, required this.deposit,
    this.minDays = 1, this.maxDays = 7, this.lateFee = 0,
    this.images = const [], this.rating = 0, this.reviewCount = 0,
    this.available = true, this.bookedDates = const [],
    this.reviews = const [], this.createdAt = '',
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) => ItemModel(
    id: json['id'] ?? '',
    ownerId: json['owner_id'] ?? '',
    ownerName: json['owner_name'] ?? '',
    ownerVerified: json['owner_verified'] ?? false,
    ownerRating: (json['owner_rating'] ?? 0).toDouble(),
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    description: json['description'] ?? '',
    brand: json['brand'] ?? '',
    size: json['size'],
    color: json['color'],
    condition: json['condition'] ?? '',
    pricePerDay: (json['price_per_day'] ?? 0).toDouble(),
    deposit: (json['deposit'] ?? 0).toDouble(),
    minDays: json['min_days'] ?? 1,
    maxDays: json['max_days'] ?? 7,
    lateFee: (json['late_fee'] ?? 0).toDouble(),
    images: List<String>.from(json['images'] ?? []),
    rating: (json['rating'] ?? 0).toDouble(),
    reviewCount: json['review_count'] ?? 0,
    available: json['available'] ?? true,
    bookedDates: (json['booked_dates'] as List? ?? [])
        .map((d) => BookedDateRange.fromJson(d)).toList(),
    reviews: (json['reviews'] as List? ?? [])
        .map((r) => ReviewModel.fromJson(r)).toList(),
    createdAt: json['created_at'] ?? '',
  );

  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'clothes': return '👗';
      case 'electronics': return '🎮';
      case 'books': return '📚';
      case 'accessories': return '🎒';
      case 'sports': return '⚽';
      case 'tools': return '🔧';
      case 'music': return '🎸';
      default: return '📦';
    }
  }
}

class BookedDateRange {
  final DateTime start;
  final DateTime end;

  BookedDateRange({required this.start, required this.end});

  factory BookedDateRange.fromJson(Map<String, dynamic> json) => BookedDateRange(
    start: DateTime.parse(json['start']),
    end: DateTime.parse(json['end']),
  );
}

// ─── Booking Model ────────────────────────────────────────────────────────────
class BookingModel {
  final String id;
  final String itemId;
  final String borrowerId;
  final String ownerId;
  final String itemName;
  final String ownerName;
  final String borrowerName;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final double pricePerDay;
  final double subtotal;
  final double deposit;
  final double total;
  final String pickupLocation;
  final String status;
  final List<String> pickupPhotos;
  final List<String> returnPhotos;
  final String createdAt;

  BookingModel({
    required this.id, required this.itemId, required this.borrowerId,
    required this.ownerId, this.itemName = '', this.ownerName = '',
    this.borrowerName = '', required this.startDate, required this.endDate,
    required this.durationDays, required this.pricePerDay,
    required this.subtotal, required this.deposit, required this.total,
    required this.pickupLocation, required this.status,
    this.pickupPhotos = const [], this.returnPhotos = const [],
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] ?? '',
    itemId: json['item_id'] ?? '',
    borrowerId: json['borrower_id'] ?? '',
    ownerId: json['owner_id'] ?? '',
    itemName: json['item_name'] ?? '',
    ownerName: json['owner_name'] ?? '',
    borrowerName: json['borrower_name'] ?? '',
    startDate: DateTime.parse(json['start_date']),
    endDate: DateTime.parse(json['end_date']),
    durationDays: json['duration_days'] ?? 0,
    pricePerDay: (json['price_per_day'] ?? 0).toDouble(),
    subtotal: (json['subtotal'] ?? 0).toDouble(),
    deposit: (json['deposit'] ?? 0).toDouble(),
    total: (json['total'] ?? 0).toDouble(),
    pickupLocation: json['pickup_location'] ?? '',
    status: json['status'] ?? '',
    pickupPhotos: List<String>.from(json['pickup_photos'] ?? []),
    returnPhotos: List<String>.from(json['return_photos'] ?? []),
    createdAt: json['created_at'] ?? '',
  );

  String get statusLabel {
    switch (status) {
      case 'pending_confirmation': return 'Pending Confirmation';
      case 'confirmed': return 'Confirmed';
      case 'pending_pickup': return 'Pending Pickup';
      case 'active': return 'Active';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'rejected': return 'Rejected';
      case 'disputed': return 'Disputed';
      default: return status;
    }
  }
}

// ─── Review Model ─────────────────────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String itemId;
  final String bookingId;
  final String reviewerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;

  ReviewModel({
    required this.id, required this.itemId, required this.bookingId,
    required this.reviewerId, required this.reviewerName,
    required this.rating, required this.comment, required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] ?? '',
    itemId: json['item_id'] ?? '',
    bookingId: json['booking_id'] ?? '',
    reviewerId: json['reviewer_id'] ?? '',
    reviewerName: json['reviewer_name'] ?? '',
    rating: json['rating'] ?? 0,
    comment: json['comment'] ?? '',
    createdAt: json['created_at'] ?? '',
  );
}

// ─── Notification Model ───────────────────────────────────────────────────────
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String createdAt;

  NotificationModel({
    required this.id, required this.userId, required this.title,
    required this.message, required this.type, required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'] ?? '',
    userId: json['user_id'] ?? '',
    title: json['title'] ?? '',
    message: json['message'] ?? '',
    type: json['type'] ?? '',
    read: json['read'] ?? false,
    createdAt: json['created_at'] ?? '',
  );
}

// ─── Category Model ───────────────────────────────────────────────────────────
class CategoryModel {
  final String id;
  final String name;
  final String icon;

  CategoryModel({required this.id, required this.name, required this.icon});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    icon: json['icon'] ?? '📦',
  );
}
