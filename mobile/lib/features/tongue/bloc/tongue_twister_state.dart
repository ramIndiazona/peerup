
import '../../../models/tongue_twister.dart';

abstract class TongueTwisterState {}

class TongueTwisterInitial extends TongueTwisterState {}

class TongueTwisterLoading extends TongueTwisterState {}

class TongueTwisterLoaded extends TongueTwisterState 
{
  final List<TongueTwister> twisters;

  TongueTwisterLoaded(this.twisters);
}

class TongueTwisterError extends TongueTwisterState {
  final String message;

  TongueTwisterError(this.message);
}
