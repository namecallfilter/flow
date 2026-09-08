import "package:flow/shared/iana_tlds.dart";

final RegExp _httpScheme = RegExp("^https?://", caseSensitive: false);
final RegExp _domainLabel = RegExp(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$");

Uri? chatLinkUri(String label) {
  final uri = Uri.tryParse(_httpScheme.hasMatch(label) ? label : "https://$label");
  if (uri == null || uri.userInfo.isNotEmpty || uri.host.length > 253) {
    return null;
  }
  final labels = uri.host.toLowerCase().split(".");
  if (labels.length < 2 ||
      !ianaTopLevelDomains.contains(labels.last) ||
      !labels.every(_domainLabel.hasMatch)) {
    return null;
  }
  return uri;
}
