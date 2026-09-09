import "package:flow/shared/chat_links.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("recognizes HTTP links and bare domains with registered TLDs", () {
    for (final label in [
      "twitch.tv/name",
      "www.youtube.com/watch?v=abc#t=3",
      "example.co.uk",
      "a.photography/gallery",
      "example.museum",
      "example.xn--p1ai",
      "xn--bcher-kva.de",
      "example.com:8080/path",
    ]) {
      expect(chatLinkUri(label), Uri.parse("https://$label"), reason: label);
    }
    expect(chatLinkUri("HTTP://Example.COM/a"), Uri.parse("http://example.com/a"));
    expect(chatLinkUri("https://example.dev"), Uri.parse("https://example.dev"));
  });

  test("leaves unknown TLDs, emails, and malformed domains as plain text", () {
    for (final label in [
      "hi.ok",
      "https://hi.ok",
      "example.notatld",
      "user@example.com",
      "https://user@example.com",
      "localhost",
      "https://localhost",
      "example..com",
      "-example.com",
      "example-.com",
      "under_score.com",
      "ftp://example.com",
      "mailto:user@example.com",
      "https://example.com:bad",
    ]) {
      expect(chatLinkUri(label), isNull, reason: label);
    }
  });

  test("preserves balanced URL punctuation, query strings, and fragments", () {
    const label = "https://en.wikipedia.org/wiki/Flow_(psychology)?a=b&c=d#History";
    expect(chatLinkUri(label).toString(), label);
  });
}
