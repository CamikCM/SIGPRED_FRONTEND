class PaginatedResponse<T> {
  final int currentPage;
  final List<T> data;
  final int? from; // 👈 puede ser null
  final int lastPage;
  final String? nextPageUrl;
  final int perPage;
  final int? to; // 👈 puede ser null
  final int total;

  PaginatedResponse({
    required this.currentPage,
    required this.data,
    this.from,
    required this.lastPage,
    required this.nextPageUrl,
    required this.perPage,
    this.to,
    required this.total,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      currentPage: json['current_page'] as int,
      data: (json['data'] as List)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      from: json['from'] == null ? null : json['from'] as int, // 👈 protegido
      lastPage: json['last_page'] as int,
      nextPageUrl: json['next_page_url'] as String?,
      perPage: json['per_page'] is int
          ? json['per_page']
          : int.tryParse(json['per_page'].toString()) ?? 15,
      to: json['to'] == null ? null : json['to'] as int, // 👈 protegido
      total: json['total'] as int,
    );
  }
}
