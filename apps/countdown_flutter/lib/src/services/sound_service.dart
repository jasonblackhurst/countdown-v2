import 'package:flutter/services.dart';

/// Abstract interface for sound playback, enabling test injection.
abstract class SoundService {
  /// Whether all sounds are currently muted.
  bool get isMuted;

  /// Toggle mute on/off. Returns the new muted state.
  bool toggleMute();

  /// Play a soft click/thud when a card is played.
  void playCardSound();

  /// Play an impact sound when a life is lost.
  void playLifeLossSound();

  /// Play a triumphant sound when the game is won.
  void playWinSound();

  /// Play a somber tone when the game is lost.
  void playLossSound();
}

/// Production implementation using system sounds and haptic feedback.
///
/// Uses [SystemSound] and [HapticFeedback] for basic audio/tactile feedback.
/// Can be enhanced later with real audio files via audioplayers.
class SystemSoundService implements SoundService {
  bool _isMuted = false;

  @override
  bool get isMuted => _isMuted;

  @override
  bool toggleMute() {
    _isMuted = !_isMuted;
    return _isMuted;
  }

  @override
  void playCardSound() {
    if (_isMuted) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  @override
  void playLifeLossSound() {
    if (_isMuted) return;
    HapticFeedback.heavyImpact();
  }

  @override
  void playWinSound() {
    if (_isMuted) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  @override
  void playLossSound() {
    if (_isMuted) return;
    HapticFeedback.heavyImpact();
  }
}
