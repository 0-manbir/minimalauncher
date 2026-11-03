import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:minimalauncher/variables/strings.dart';
import 'package:path_provider/path_provider.dart';

class GitHubReleaseUpdate {
  const GitHubReleaseUpdate({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assetName,
  });

  final String version;
  final String releaseNotes;
  final Uri downloadUrl;
  final String assetName;

  static GitHubReleaseUpdate parse(Map<String, dynamic> release) {
    final tag = release['tag_name'];
    if (tag is! String || tag.trim().isEmpty) {
      throw const UpdateException('The latest release has no version tag.');
    }

    final version = tag.trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (!_ParsedVersion.tryParse(version).isValid) {
      throw UpdateException('The latest release has an invalid version: $tag');
    }

    final assets = release['assets'];
    if (assets is! List) {
      throw const UpdateException('The latest release has no valid assets.');
    }

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          asset['name'] == updateApkAssetName) {
        apkAsset = asset;
        break;
      }
    }
    if (apkAsset == null) {
      throw UpdateException(
        'APK asset "$updateApkAssetName" was not found in the latest release.',
      );
    }

    final downloadUrl = apkAsset['browser_download_url'];
    final uri = downloadUrl is String ? Uri.tryParse(downloadUrl) : null;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const UpdateException(
        'The APK asset has an invalid download URL.',
      );
    }

    final body = release['body'];
    return GitHubReleaseUpdate(
      version: version,
      releaseNotes: body is String && body.trim().isNotEmpty
          ? body.trim()
          : 'No release notes were provided.',
      downloadUrl: uri,
      assetName: updateApkAssetName,
    );
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GitHubUpdateService {
  GitHubUpdateService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  Future<GitHubReleaseUpdate> fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$updateGitHubOwner/$updateGitHubRepository/releases/latest',
    );

    late final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'MinimalLauncher-UpdateManager',
        },
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const UpdateException('The GitHub request timed out.');
    } on http.ClientException catch (error) {
      throw UpdateException('Could not reach GitHub: ${error.message}');
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw const UpdateException(
          'No published GitHub release was found for this repository.',
        );
      }
      if (response.statusCode == 403) {
        throw const UpdateException(
          'GitHub temporarily rate-limited the update check. Try again later.',
        );
      }
      throw UpdateException(
        'GitHub returned an unexpected response (${response.statusCode}).',
      );
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const UpdateException('GitHub returned invalid release data.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('GitHub returned an invalid release.');
    }

    return GitHubReleaseUpdate.parse(decoded);
  }

  Future<File> downloadApk(
    GitHubReleaseUpdate release, {
    required void Function(int received, int? total) onProgress,
  }) async {
    File? file;
    IOSink? sink;
    var received = 0;
    int? total;

    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final directory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}updates',
      );
      await directory.create(recursive: true);
      file = File(
        '${directory.path}${Platform.pathSeparator}'
        'update-${DateTime.now().microsecondsSinceEpoch}.apk',
      );

      final request = http.Request('GET', release.downloadUrl);
      request.headers['User-Agent'] = 'MinimalLauncher-UpdateManager';
      final response = await _client.send(request).timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode != 200) {
        throw UpdateException(
          'APK download failed (${response.statusCode}).',
        );
      }

      total = response.contentLength;
      sink = file.openWrite();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0 || (total != null && received != total)) {
        throw const UpdateException(
          'The APK download was interrupted. Please try again.',
        );
      }
      return file;
    } on UpdateException {
      await _deletePartialDownload(file, sink);
      rethrow;
    } on TimeoutException {
      await _deletePartialDownload(file, sink);
      throw const UpdateException('The APK download timed out.');
    } on http.ClientException catch (error) {
      await _deletePartialDownload(file, sink);
      throw UpdateException(
          'The APK download was interrupted: ${error.message}');
    } on FileSystemException catch (error) {
      await _deletePartialDownload(file, sink);
      throw UpdateException('Could not save the APK: ${error.message}');
    } catch (error) {
      await _deletePartialDownload(file, sink);
      throw UpdateException('APK download failed: $error');
    }
  }

  Future<void> _deletePartialDownload(File? file, IOSink? sink) async {
    if (sink != null) {
      await sink.close();
    }
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}

bool isUpdateAvailable(String latestVersion, String installedVersion) =>
    compareAppVersions(latestVersion, installedVersion) > 0;

int compareAppVersions(String first, String second) =>
    _ParsedVersion.parse(first).compareTo(_ParsedVersion.parse(second));

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
    required this.build,
  });

  static final _invalid = _ParsedVersion(
    major: -1,
    minor: -1,
    patch: -1,
    prerelease: const [],
    build: null,
  );

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;
  final int? build;

  bool get isValid => major >= 0;

  static _ParsedVersion parse(String value) {
    final parsed = tryParse(value);
    if (!parsed.isValid) {
      throw UpdateException('Invalid version number: $value');
    }
    return parsed;
  }

  static _ParsedVersion tryParse(String value) {
    final match = RegExp(
      r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?'
      r'(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?$',
    ).firstMatch(value.trim());
    if (match == null) return _invalid;
    final major = int.tryParse(match.group(1)!);
    final minor = int.tryParse(match.group(2) ?? '0');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) return _invalid;
    return _ParsedVersion(
      major: major,
      minor: minor,
      patch: patch,
      prerelease: match.group(4)?.split('.') ?? const [],
      build: int.tryParse(match.group(5) ?? ''),
    );
  }

  @override
  int compareTo(_ParsedVersion other) {
    final components = [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
    ];
    for (final comparison in components) {
      if (comparison != 0) return comparison;
    }

    if (prerelease.isEmpty && other.prerelease.isNotEmpty) return 1;
    if (prerelease.isNotEmpty && other.prerelease.isEmpty) return -1;
    for (var index = 0; index < prerelease.length; index++) {
      if (index >= other.prerelease.length) return 1;
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final comparison = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftNumber != null
              ? -1
              : rightNumber != null
                  ? 1
                  : left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    if (prerelease.length < other.prerelease.length) return -1;

    if (build != null && other.build != null) {
      return build!.compareTo(other.build!);
    }
    return 0;
  }
}
