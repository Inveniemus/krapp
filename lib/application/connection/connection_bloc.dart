import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_riverpod/all.dart';
import 'package:krpc_dart/krpc_dart.dart';
import 'package:meta/meta.dart';

import '../../krpc/client.dart';

import '../../domain/connection/ip.dart';
import '../../domain/connection/port.dart';
import '../../domain/connection/connection_parameters.dart';

part 'connection_event.dart';
part 'connection_state.dart';

class KrpcConnectionBloc
    extends Bloc<KrpcConnectionEvent, KrpcConnectionState> {
  ConnectionParameters _parameters;
  KrpcClient _client;

  KrpcConnectionBloc() : super(KrpcDisconnectedState()) {
    _client = ProviderContainer().read(clientProvider);
    _parameters = ConnectionParameters();
  }

  @override
  Stream<KrpcConnectionState> mapEventToState(
    KrpcConnectionEvent event,
  ) async* {
    if (event is ConnectionParametersEvent) {
      _updateConnectionParameters(event);
      yield _validityState();
    } else if (event is RPCConnectionRequest) {
      yield KrpcConnectingState();

      if (_parameters.rpcValid || _parameters.valid) {
        yield* _tryToConnectRPC();
      } else {
        yield KprcConnectionValidityState(ConnectionValidity.invalid);
      }
    } else if (event is DisconnectKrpcEvent) {
      yield* _tryToDisconnect();
    }
  }

  void _updateConnectionParameters(ConnectionParametersEvent event) {
    if (event is IpParameterEvent) {
      _parameters.ip = event.ip;
    } else if (event is RpcPortParameterEvent) {
      _parameters.rpcPort = event.port;
    } else if (event is StreamPortParameterEvent) {
      _parameters.streamPort = event.port;
    } else if (event is ClientNameParameterEvent) {
      _parameters.clientName = event.string;
    }
  }

  KrpcConnectionState _validityState() {
    if (_parameters.valid) {
      return KprcConnectionValidityState(ConnectionValidity.valid);
    } else if (_parameters.rpcValid) {
      return KprcConnectionValidityState(ConnectionValidity.rpcOnly);
    } else {
      return KprcConnectionValidityState(ConnectionValidity.invalid);
    }
  }

  Stream<KrpcConnectionState> _tryToConnectRPC() async* {
    try {
      _client.ip = _parameters.ip.value;
      _client.rpcPort = int.parse(_parameters.rpcPort.value);
      _client.clientName = _parameters.clientName ?? 'KrApp';
      await _client.connectRPC();
      yield KrpcConnectedState();
    } on Exception catch (e, s) {
      yield KrpcConnectionErrorState(e.toString(), s.toString());
    }
  }

  Stream<KrpcConnectionState> _tryToDisconnect() async* {
    try {
      await _client.disconnect();
      yield KrpcDisconnectedState();
    } on Exception catch (e, s) {
      yield KrpcConnectionErrorState(e.toString(), s.toString());
    } finally {
      _client = null;
    }
  }

  // Testing stuff
  void setTestingContainer(ProviderContainer testingContainer) {
    _client = testingContainer.read(clientProvider);
  }
}
