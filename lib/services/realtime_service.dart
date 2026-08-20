import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../core/api_client.dart';
import '../models/notification_model.dart';
import '../models/realtime_config.dart';
import '../models/survey_model.dart';

typedef NotificationRealtimeHandler = void Function(NotificationModel notification);
typedef SurveyRealtimeHandler = void Function({
  required String action,
  SurveyModel? survey,
  int? surveyId,
});

/// Client realtime Laravel Reverb (notifications + sondages).
class RealtimeService {
  RealtimeService(this._api);

  final ApiClient _api;

  PusherChannelsClient? _client;
  StreamSubscription<void>? _connectionSub;
  final List<StreamSubscription<ChannelReadEvent>> _eventSubs = [];
  final List<void Function()> _subscribeFns = [];
  final List<void Function()> _unsubscribeFns = [];
  bool _started = false;

  Future<void> start({
    required int userId,
    required bool canManage,
    NotificationRealtimeHandler? onNotification,
    SurveyRealtimeHandler? onSurveyChanged,
  }) async {
    await stop();
    _started = true;

    try {
      final configRes = await _api.get<RealtimeConfig>(
        '/realtime/config',
        parser: (raw) => RealtimeConfig.fromJson(raw as Map<String, dynamic>),
      );
      final config = configRes.data;
      if (config == null || config.key.isEmpty) {
        debugPrint('Realtime: config manquante');
        return;
      }

      final host = (config.host == '127.0.0.1' || config.host == 'localhost')
          ? ApiConfig.host
          : config.host;

      final authUri = Uri.parse(
        config.authEndpoint.isNotEmpty
            ? _rewriteLocalHost(config.authEndpoint, host)
            : '${ApiConfig.baseUrl}/broadcasting/auth',
      );

      final options = PusherChannelsOptions.fromHost(
        scheme: config.wsScheme,
        host: host,
        key: config.key,
        port: config.port,
        shouldSupplyMetadataQueries: true,
      );

      final client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          debugPrint('Realtime WS error: $exception');
          refresh();
        },
      );
      _client = client;

      final token = _api.token ?? '';
      final authHeaders = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      void track(dynamic channel) {
        _subscribeFns.add(() => channel.subscribeIfNotUnsubscribed());
        _unsubscribeFns.add(() {
          try {
            channel.unsubscribe();
          } catch (_) {}
        });
      }

      // Canal privé user → notifications
      final userChannelName = config.userChannel.isNotEmpty
          ? config.userChannel
          : 'private-user.$userId';
      final userChannel = client.privateChannel(
        userChannelName,
        authorizationDelegate:
            EndpointAuthorizableChannelTokenAuthorizationDelegate
                .forPrivateChannel(
          authorizationEndpoint: authUri,
          headers: authHeaders,
        ),
      );
      track(userChannel);

      if (onNotification != null) {
        _eventSubs.add(
          userChannel.bind('notification.created').listen((event) {
            final n = _parseNotification(event.data);
            if (n != null) onNotification(n);
          }),
        );
      }

      // Canal public surveys → employés + managers
      final surveysChannel = client.publicChannel(config.surveysChannel);
      track(surveysChannel);
      if (onSurveyChanged != null) {
        _eventSubs.add(
          surveysChannel.bind('survey.changed').listen((event) {
            final parsed = _parseSurveyEvent(event.data);
            if (parsed != null) {
              onSurveyChanged(
                action: parsed.$1,
                survey: parsed.$2,
                surveyId: parsed.$3,
              );
            }
          }),
        );
      }

      // Canal managers (si autorisé)
      if (canManage &&
          config.managersChannel != null &&
          config.managersChannel!.isNotEmpty &&
          onSurveyChanged != null) {
        final managersChannel = client.privateChannel(
          config.managersChannel!,
          authorizationDelegate:
              EndpointAuthorizableChannelTokenAuthorizationDelegate
                  .forPrivateChannel(
            authorizationEndpoint: authUri,
            headers: authHeaders,
          ),
        );
        track(managersChannel);
        _eventSubs.add(
          managersChannel.bind('survey.changed').listen((event) {
            final parsed = _parseSurveyEvent(event.data);
            if (parsed != null) {
              onSurveyChanged(
                action: parsed.$1,
                survey: parsed.$2,
                surveyId: parsed.$3,
              );
            }
          }),
        );
      }

      _connectionSub = client.onConnectionEstablished.listen((_) {
        for (final fn in _subscribeFns) {
          fn();
        }
      });

      client.connect();
      debugPrint(
        'Realtime: $host:${config.port} user=$userChannelName surveys=${config.surveysChannel}',
      );
    } catch (e, st) {
      debugPrint('Realtime start failed: $e\n$st');
      await stop();
    }
  }

  NotificationModel? _parseNotification(dynamic raw) {
    try {
      final map = _asMap(raw);
      if (map == null) return null;
      final data = map['data'];
      if (data is Map) {
        return NotificationModel.fromJson(Map<String, dynamic>.from(data));
      }
      if (map.containsKey('message') && map.containsKey('id')) {
        return NotificationModel.fromJson(map);
      }
    } catch (e) {
      debugPrint('Realtime notification parse error: $e');
    }
    return null;
  }

  (String, SurveyModel?, int?)? _parseSurveyEvent(dynamic raw) {
    try {
      final map = _asMap(raw);
      if (map == null) return null;
      final action = map['action']?.toString() ?? 'updated';
      final idRaw = map['survey_id'];
      final surveyId = idRaw == null
          ? null
          : (idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw'));
      SurveyModel? survey;
      final data = map['data'];
      if (data is Map) {
        survey = SurveyModel.fromJson(Map<String, dynamic>.from(data));
      }
      return (action, survey, surveyId ?? survey?.id);
    } catch (e) {
      debugPrint('Realtime survey parse error: $e');
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    dynamic payload = raw;
    if (payload is String) {
      payload = jsonDecode(payload);
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  String _rewriteLocalHost(String url, String host) {
    try {
      final uri = Uri.parse(url);
      if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
        return uri.replace(host: host).toString();
      }
    } catch (_) {}
    return url;
  }

  Future<void> stop() async {
    _started = false;
    for (final sub in _eventSubs) {
      await sub.cancel();
    }
    _eventSubs.clear();
    await _connectionSub?.cancel();
    _connectionSub = null;
    for (final fn in _unsubscribeFns) {
      fn();
    }
    _unsubscribeFns.clear();
    _subscribeFns.clear();
    try {
      _client?.disconnect();
    } catch (_) {}
    try {
      _client?.dispose();
    } catch (_) {}
    _client = null;
  }

  bool get isStarted => _started;
}
