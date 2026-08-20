class RealtimeConfig {
  RealtimeConfig({
    required this.key,
    required this.host,
    required this.port,
    required this.scheme,
    required this.authEndpoint,
    required this.userChannel,
    this.surveysChannel = 'surveys',
    this.managersChannel,
  });

  final String key;
  final String host;
  final int port;
  final String scheme;
  final String authEndpoint;
  final String userChannel;
  final String surveysChannel;
  final String? managersChannel;

  factory RealtimeConfig.fromJson(Map<String, dynamic> json) {
    final channels = json['channels'];
    final channelMap =
        channels is Map<String, dynamic> ? channels : <String, dynamic>{};

    return RealtimeConfig(
      key: json['key']?.toString() ?? '',
      host: json['host']?.toString() ?? '127.0.0.1',
      port: (json['port'] is num)
          ? (json['port'] as num).toInt()
          : int.tryParse('${json['port']}') ?? 8080,
      scheme: json['scheme']?.toString() ?? 'http',
      authEndpoint: json['auth_endpoint']?.toString() ?? '',
      userChannel: channelMap['user']?.toString() ?? '',
      surveysChannel: channelMap['surveys']?.toString() ?? 'surveys',
      managersChannel: channelMap['managers']?.toString(),
    );
  }

  String get wsScheme => scheme == 'https' ? 'wss' : 'ws';
}
