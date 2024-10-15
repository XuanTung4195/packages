// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// Autogenerated from Pigeon (v22.5.0), do not edit directly.
// See also: https://pub.dev/packages/pigeon
// ignore_for_file: public_member_api_docs, non_constant_identifier_names, avoid_as, unused_import, unnecessary_parenthesis, unnecessary_import, no_leading_underscores_for_local_identifiers
// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:typed_data' show Float64List, Int32List, Int64List, Uint8List;
import 'package:flutter/foundation.dart' show ReadBuffer, WriteBuffer;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_android/src/messages.g.dart';


class _PigeonCodec extends StandardMessageCodec {
  const _PigeonCodec();
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is int) {
      buffer.putUint8(4);
      buffer.putInt64(value);
    }    else if (value is TextureMessage) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    }    else if (value is LoopingMessage) {
      buffer.putUint8(130);
      writeValue(buffer, value.encode());
    }    else if (value is VolumeMessage) {
      buffer.putUint8(131);
      writeValue(buffer, value.encode());
    }    else if (value is PlaybackSpeedMessage) {
      buffer.putUint8(132);
      writeValue(buffer, value.encode());
    }    else if (value is PositionMessage) {
      buffer.putUint8(133);
      writeValue(buffer, value.encode());
    }    else if (value is CreateMessage) {
      buffer.putUint8(134);
      writeValue(buffer, value.encode());
    }    else if (value is SetDataSourceMessage) {
      buffer.putUint8(135);
      writeValue(buffer, value.encode());
    }    else if (value is MixWithOthersMessage) {
      buffer.putUint8(136);
      writeValue(buffer, value.encode());
    }    else if (value is VideoResolutionMessage) {
      buffer.putUint8(137);
      writeValue(buffer, value.encode());
    }    else if (value is VideoResolutionData) {
      buffer.putUint8(138);
      writeValue(buffer, value.encode());
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 129: 
        return TextureMessage.decode(readValue(buffer)!);
      case 130: 
        return LoopingMessage.decode(readValue(buffer)!);
      case 131: 
        return VolumeMessage.decode(readValue(buffer)!);
      case 132: 
        return PlaybackSpeedMessage.decode(readValue(buffer)!);
      case 133: 
        return PositionMessage.decode(readValue(buffer)!);
      case 134: 
        return CreateMessage.decode(readValue(buffer)!);
      case 135: 
        return SetDataSourceMessage.decode(readValue(buffer)!);
      case 136: 
        return MixWithOthersMessage.decode(readValue(buffer)!);
      case 137: 
        return VideoResolutionMessage.decode(readValue(buffer)!);
      case 138: 
        return VideoResolutionData.decode(readValue(buffer)!);
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

abstract class TestHostVideoPlayerApi {
  static TestDefaultBinaryMessengerBinding? get _testBinaryMessengerBinding => TestDefaultBinaryMessengerBinding.instance;
  static const MessageCodec<Object?> pigeonChannelCodec = _PigeonCodec();

  void initialize();

  TextureMessage create(CreateMessage msg);

  void dispose(TextureMessage msg);

  void setLooping(LoopingMessage msg);

  void setVolume(VolumeMessage msg);

  void setPlaybackSpeed(PlaybackSpeedMessage msg);

  void play(TextureMessage msg);

  PositionMessage position(TextureMessage msg);

  void seekTo(PositionMessage msg);

  void pause(TextureMessage msg);

  void setMixWithOthers(MixWithOthersMessage msg);

  void changeDataSource(SetDataSourceMessage msg);

  void setVideoResolution(VideoResolutionMessage msg);

  List<VideoResolutionData> getVideoResolutions(TextureMessage msg);

  static void setUp(TestHostVideoPlayerApi? api, {BinaryMessenger? binaryMessenger, String messageChannelSuffix = '',}) {
    messageChannelSuffix = messageChannelSuffix.isNotEmpty ? '.$messageChannelSuffix' : '';
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.initialize$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          try {
            api.initialize();
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.create$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.create was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final CreateMessage? arg_msg = (args[0] as CreateMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.create was null, expected non-null CreateMessage.');
          try {
            final TextureMessage output = api.create(arg_msg!);
            return <Object?>[output];
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.dispose$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.dispose was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final TextureMessage? arg_msg = (args[0] as TextureMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.dispose was null, expected non-null TextureMessage.');
          try {
            api.dispose(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setLooping$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setLooping was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final LoopingMessage? arg_msg = (args[0] as LoopingMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setLooping was null, expected non-null LoopingMessage.');
          try {
            api.setLooping(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVolume$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVolume was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final VolumeMessage? arg_msg = (args[0] as VolumeMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVolume was null, expected non-null VolumeMessage.');
          try {
            api.setVolume(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setPlaybackSpeed$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setPlaybackSpeed was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final PlaybackSpeedMessage? arg_msg = (args[0] as PlaybackSpeedMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setPlaybackSpeed was null, expected non-null PlaybackSpeedMessage.');
          try {
            api.setPlaybackSpeed(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.play$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.play was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final TextureMessage? arg_msg = (args[0] as TextureMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.play was null, expected non-null TextureMessage.');
          try {
            api.play(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.position$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.position was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final TextureMessage? arg_msg = (args[0] as TextureMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.position was null, expected non-null TextureMessage.');
          try {
            final PositionMessage output = api.position(arg_msg!);
            return <Object?>[output];
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.seekTo$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.seekTo was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final PositionMessage? arg_msg = (args[0] as PositionMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.seekTo was null, expected non-null PositionMessage.');
          try {
            api.seekTo(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.pause$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.pause was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final TextureMessage? arg_msg = (args[0] as TextureMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.pause was null, expected non-null TextureMessage.');
          try {
            api.pause(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setMixWithOthers$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setMixWithOthers was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final MixWithOthersMessage? arg_msg = (args[0] as MixWithOthersMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setMixWithOthers was null, expected non-null MixWithOthersMessage.');
          try {
            api.setMixWithOthers(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.changeDataSource$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.changeDataSource was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final SetDataSourceMessage? arg_msg = (args[0] as SetDataSourceMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.changeDataSource was null, expected non-null SetDataSourceMessage.');
          try {
            api.changeDataSource(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVideoResolution$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVideoResolution was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final VideoResolutionMessage? arg_msg = (args[0] as VideoResolutionMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.setVideoResolution was null, expected non-null VideoResolutionMessage.');
          try {
            api.setVideoResolution(arg_msg!);
            return wrapResponse(empty: true);
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
    {
      final BasicMessageChannel<Object?> pigeonVar_channel = BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.getVideoResolutions$messageChannelSuffix', pigeonChannelCodec,
          binaryMessenger: binaryMessenger);
      if (api == null) {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, null);
      } else {
        _testBinaryMessengerBinding!.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(pigeonVar_channel, (Object? message) async {
          assert(message != null,
          'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.getVideoResolutions was null.');
          final List<Object?> args = (message as List<Object?>?)!;
          final TextureMessage? arg_msg = (args[0] as TextureMessage?);
          assert(arg_msg != null,
              'Argument for dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.getVideoResolutions was null, expected non-null TextureMessage.');
          try {
            final List<VideoResolutionData> output = api.getVideoResolutions(arg_msg!);
            return <Object?>[output];
          } on PlatformException catch (e) {
            return wrapResponse(error: e);
          }          catch (e) {
            return wrapResponse(error: PlatformException(code: 'error', message: e.toString()));
          }
        });
      }
    }
  }
}
