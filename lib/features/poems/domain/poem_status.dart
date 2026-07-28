/// Moderation status for a poem. Maps to public.poem_status.
enum PoemStatus {
  pending,
  approved,
  rejected;

  static PoemStatus fromDb(String value) {
    switch (value.trim()) {
      case 'pending':
        return PoemStatus.pending;
      case 'approved':
        return PoemStatus.approved;
      case 'rejected':
        return PoemStatus.rejected;
      default:
        throw FormatException('Unknown poem status: $value');
    }
  }

  String get dbValue => name;

  /// Spanish label for the raw status (ignores hidden).
  String get labelEs {
    switch (this) {
      case PoemStatus.pending:
        return 'En revisión';
      case PoemStatus.approved:
        return 'Publicado';
      case PoemStatus.rejected:
        return 'Rechazado';
    }
  }
}
