// import 'package:flutter_webrtc/flutter_webrtc.dart';

// import '../config/app_config.dart';

// class ActiveWebRtcCall {
//   ActiveWebRtcCall({
//     required this.pc,
//     required this.localStream,
//     this.remoteStream,
//   });

//   final RTCPeerConnection pc;
//   final MediaStream localStream;
//   MediaStream? remoteStream;
// }

// class WebRtcService {
//   Map<String, dynamic> _config() {
//     final servers = [
//       {
//         'urls': [AppConfig.stunUrl],
//       },
//       if (AppConfig.turnUrl.isNotEmpty)
//         {
//           'urls': [AppConfig.turnUrl],
//           'username': AppConfig.turnUsername,
//           'credential': AppConfig.turnCredential,
//         },
//     ];
//     return {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
//   }

//   Future<ActiveWebRtcCall> createCall({
//     required void Function(Map<String, dynamic> candidate) onSendIceCandidate,
//     required void Function(MediaStream remoteStream) onRemoteStream,
//     required void Function(RTCPeerConnectionState state) onState,
//   }) async {
//     final local = await navigator.mediaDevices.getUserMedia({
//       'audio': true,
//       'video': false,
//     });
//     final pc = await createPeerConnection(_config());
//     if (local.getAudioTracks().isNotEmpty) {
//       pc.addTrack(local.getAudioTracks().first, local);
//     }
//     pc.onIceCandidate =
//         (candidate) => onSendIceCandidate({
//           'candidate': candidate.candidate,
//           'sdpMid': candidate.sdpMid,
//           'sdpMLineIndex': candidate.sdpMLineIndex,
//         });
//     pc.onTrack = (event) {
//       if (event.streams.isNotEmpty) onRemoteStream(event.streams.first);
//     };
//     pc.onConnectionState = onState;
//     return ActiveWebRtcCall(pc: pc, localStream: local);
//   }

//   Future<Map<String, dynamic>> createOffer(ActiveWebRtcCall call) async {
//     final offer = await call.pc.createOffer({
//       'offerToReceiveAudio': 1,
//       'offerToReceiveVideo': 0,
//     });
//     await call.pc.setLocalDescription(offer);
//     return offer.toMap();
//   }

//   Future<void> acceptOffer(
//     ActiveWebRtcCall call,
//     Map<String, dynamic> offer,
//   ) async {
//     await call.pc.setRemoteDescription(
//       RTCSessionDescription(
//         offer['sdp'] as String? ?? '',
//         offer['type'] as String? ?? 'offer',
//       ),
//     );
//   }

//   Future<Map<String, dynamic>> createAnswer(ActiveWebRtcCall call) async {
//     final answer = await call.pc.createAnswer();
//     await call.pc.setLocalDescription(answer);
//     return answer.toMap();
//   }

//   Future<void> acceptAnswer(
//     ActiveWebRtcCall call,
//     Map<String, dynamic> answer,
//   ) async {
//     await call.pc.setRemoteDescription(
//       RTCSessionDescription(
//         answer['sdp'] as String? ?? '',
//         answer['type'] as String? ?? 'answer',
//       ),
//     );
//   }

//   Future<void> addIceCandidate(
//     ActiveWebRtcCall call,
//     Map<String, dynamic> candidate,
//   ) async {
//     await call.pc.addCandidate(
//       RTCIceCandidate(
//         candidate['candidate'] as String? ?? '',
//         candidate['sdpMid'] as String?,
//         candidate['sdpMLineIndex'] as int?,
//       ),
//     );
//   }

//   Future<void> dispose(ActiveWebRtcCall call) async {
//     await call.pc.close();
//     await call.localStream.dispose();
//     await call.remoteStream?.dispose();
//   }
// }

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';

class ActiveWebRtcCall {
  ActiveWebRtcCall({
    required this.pc,
    required this.localStream,
    this.remoteStream,
  });

  final RTCPeerConnection pc;
  final MediaStream localStream;
  MediaStream? remoteStream;
}

class WebRtcService {
  Map<String, dynamic> _config() {
    final servers = [
      {
        'urls': [AppConfig.stunUrl],
      },
      if (AppConfig.turnUrl.isNotEmpty)
        {
          'urls': [AppConfig.turnUrl],
          'username': AppConfig.turnUsername,
          'credential': AppConfig.turnCredential,
        },
    ];

    return {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
  }

  Future<ActiveWebRtcCall> createCall({
    required void Function(Map<String, dynamic> candidate) onSendIceCandidate,
    required void Function(MediaStream remoteStream) onRemoteStream,
    required void Function(RTCPeerConnectionState state) onState,
  }) async {
    final local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    final pc = await createPeerConnection(_config());

    for (final track in local.getAudioTracks()) {
      await pc.addTrack(track, local);
    }

    pc.onIceCandidate = (candidate) {
      final candidateValue = candidate.candidate;

      if (candidateValue == null || candidateValue.isEmpty) {
        return;
      }

      onSendIceCandidate({
        'candidate': candidateValue,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams.first);
      }
    };

    pc.onConnectionState = onState;

    return ActiveWebRtcCall(pc: pc, localStream: local);
  }

  Future<Map<String, dynamic>> createOffer(
    ActiveWebRtcCall call, {
    bool iceRestart = false,
  }) async {
    final offer = await call.pc.createOffer({
      if (iceRestart) 'iceRestart': true,
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await call.pc.setLocalDescription(offer);

    return offer.toMap();
  }

  Future<void> acceptOffer(
    ActiveWebRtcCall call,
    Map<String, dynamic> offer,
  ) async {
    final sdp = offer['sdp'];

    if (sdp is! String || sdp.isEmpty) {
      throw StateError('Invalid WebRTC offer SDP');
    }

    final type = offer['type'];

    await call.pc.setRemoteDescription(
      RTCSessionDescription(
        sdp,
        type is String && type.isNotEmpty ? type : 'offer',
      ),
    );
  }

  Future<Map<String, dynamic>> createAnswer(ActiveWebRtcCall call) async {
    final answer = await call.pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await call.pc.setLocalDescription(answer);

    return answer.toMap();
  }

  Future<void> acceptAnswer(
    ActiveWebRtcCall call,
    Map<String, dynamic> answer,
  ) async {
    final sdp = answer['sdp'];

    if (sdp is! String || sdp.isEmpty) {
      throw StateError('Invalid WebRTC answer SDP');
    }

    final type = answer['type'];

    await call.pc.setRemoteDescription(
      RTCSessionDescription(
        sdp,
        type is String && type.isNotEmpty ? type : 'answer',
      ),
    );
  }

  Future<void> addIceCandidate(
    ActiveWebRtcCall call,
    Map<String, dynamic> candidate,
  ) async {
    final candidateValue = candidate['candidate'];

    if (candidateValue is! String || candidateValue.isEmpty) {
      return;
    }

    final rawIndex = candidate['sdpMLineIndex'];

    int? sdpMLineIndex;

    if (rawIndex is int) {
      sdpMLineIndex = rawIndex;
    } else if (rawIndex is num) {
      sdpMLineIndex = rawIndex.toInt();
    }

    await call.pc.addCandidate(
      RTCIceCandidate(
        candidateValue,
        candidate['sdpMid'] as String?,
        sdpMLineIndex,
      ),
    );
  }

  Future<void> dispose(ActiveWebRtcCall call) async {
    try {
      await call.pc.close();
    } catch (_) {}

    try {
      await call.localStream.dispose();
    } catch (_) {}

    try {
      await call.remoteStream?.dispose();
    } catch (_) {}
  }
}
