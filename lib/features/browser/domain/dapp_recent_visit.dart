final class DappRecentVisit {
  const DappRecentVisit({
    required this.domain,
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  final String domain;
  final String title;
  final String url;
  final DateTime visitedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DappRecentVisit &&
            other.domain == domain &&
            other.title == title &&
            other.url == url &&
            other.visitedAt == visitedAt;
  }

  @override
  int get hashCode => Object.hash(domain, title, url, visitedAt);
}
