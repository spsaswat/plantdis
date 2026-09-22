import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class CardTestFirestore extends FirebaseFirestorePlatform {
  List<Map<String, dynamic>> images = [];
  Object? queryError;
  Future<void>? deletion;
  final deleted = <String>[];
  final updated = <String>[];
  final queried = <String>[];

  void reset() {
    images = [];
    queryError = null;
    deletion = null;
    deleted.clear();
    updated.clear();
    queried.clear();
  }

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;
  @override
  Settings settings = const Settings();
  @override
  CollectionReferencePlatform collection(String path) =>
      _Collection(this, path);
  @override
  DocumentReferencePlatform doc(String path) => _Document(this, path);
}

class _Collection extends CollectionReferencePlatform {
  _Collection(this.store, String path) : super(store, path) {
    parameters.addAll({
      'where': <List<dynamic>>[],
      'orderBy': <List<dynamic>>[],
    });
  }
  final CardTestFirestore store;
  @override
  QueryPlatform where(List<List<dynamic>> conditions) {
    expect(conditions.single[0].toString(), contains('plantId'));
    expect(conditions.single[2], 'plant_001');
    return this;
  }

  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) => this;
  @override
  Future<QuerySnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async {
    store.queried.add(path);
    if (store.queryError != null) throw store.queryError!;
    return QuerySnapshotPlatform(
      store.images
          .map(
            (data) => DocumentSnapshotPlatform(
              store,
              '$path/${data['imageId']}',
              data,
              PigeonSnapshotMetadata(
                hasPendingWrites: false,
                isFromCache: false,
              ),
            ),
          )
          .toList(),
      [],
      SnapshotMetadataPlatform(false, false),
    );
  }

  @override
  DocumentReferencePlatform doc([String? id]) => _Document(store, '$path/$id');
}

class _Document extends DocumentReferencePlatform {
  _Document(this.store, String path) : super(store, path);
  final CardTestFirestore store;
  @override
  Future<void> delete() async {
    store.deleted.add(path);
    await store.deletion;
  }

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {
    store.updated.add(path);
  }
}

class CardTestUser extends UserPlatform {
  CardTestUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'test-user',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _MultiFactor extends Fake implements MultiFactorPlatform {}

/// A tiny valid image returned without sockets or DNS. Other requests fail loudly.
class ImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _ImageClient();
}

class _ImageClient extends Fake implements HttpClient {
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    expect(url.host, 'test.invalid');
    return _ImageRequest();
  }

  @override
  void close({bool force = false}) {}
}

class _ImageRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  static final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1X8AAAAASUVORK5CYII=',
  );
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
