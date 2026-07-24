/// Risk level of a Wiki patch.
enum PatchRiskLevel {
  /// Low risk: minor edits, additions only.
  low,

  /// Medium risk: modifications to existing content.
  medium,

  /// High risk: significant changes, potential data loss.
  high,

  /// Critical: major restructuring or deletions.
  critical,
}

/// Extension for risk level comparison.
extension PatchRiskLevelX on PatchRiskLevel {
  bool get requiresSecondaryConfirmation =>
      this == PatchRiskLevel.high || this == PatchRiskLevel.critical;
}
